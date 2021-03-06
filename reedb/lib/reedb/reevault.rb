# ====================================================
# Copyright 2015 Lonely Robot (see @author)
# @author: Katharina Sabel | www.2rsoftworks.de
#
# Distributed under the GNU Lesser GPL Version 3
# (See accompanying LICENSE file or get a copy at
# 	https://www.gnu.org/licenses/lgpl.html)
# ====================================================

# => Vault internals
require_relative 'datafile'

# => Import custom errors
require_relative 'errors/encryption_errors'
require_relative 'errors/vault_errors'

# => Import utilities and tools
require_relative 'utils/utilities'
require_relative 'utils/sorting'
require_relative 'utils/logger'

# => Import security package classes
require_relative 'security/multifish'
require_relative 'security/twofish'
require_relative 'security/aes'

# => Import internals
require 'fileutils'
require 'socket'
require 'json'
require 'yaml'
require 'etc'

module Reedb
	class ReeVault

		attr_reader :path

		# Encryption handler to be used by the vault files
		#
		attr_reader :crypt

		# Indicates the size of the vault as per data file entries.
		# Is updated with every header cache and write cycle.
		#
		attr_reader :size

		# Holds a hash of possible values that header files in this vault
		# can have. Fields need to be specified by name and a type. To choose
		# from 'single', 'list' and 'tree' (var, list, dict)
		#
		attr_reader :header_set

		# Constructor for a vault with name, path and encryption enum.
		# Valid encryption parameters are :aes, :twofish, :multi and :auto_fill
		#
		def initialize(name, path, encprytion, header_override = nil)
			@already_logging = false

			# Header maps
			@headers = {}
			@hgroups = {}

			# Fileset
			@locked = false
			@locks = []

			# Defines the default (and boring vanilla) header set
			# TODO: Get the header set via config and init that instead!
			@header_set = header_override ? header_override : { 'urls' => 'list', 'tags' => 'list' }

			# Make the path available as an object variable
			construct_path("#{name}", "#{path}")

			# Init ecnryption module. So @crypt must not be nil after this
			init_encryption(encprytion)

			# Setup the secure config to false by default. Change this?
			self.secure_config(false)
			return self
		end

		def secure_config(boolean = true)
			@secure_config = boolean
			return self
		end

		# Fields can be added to a vault header BUT NOT REMOVED AGAIN!
		# So be careful what you put in your header.
		# (aka upgrade yes, downgrade noooo)
		#
		# Unused fields can remain blank but need to stay in a vaults header list
		# for backwards compatiblity
		#
		def add_header_field(name, type)
			@header_set[name] = type unless @header_set[name]
		end


		# Pokes if a vault exists
		def try?
			return self.includes?('config')
		end

		# Counts the vault contents and returns an Integer
		# WITHOUT HAVING TO UNLOCK THE VAULT!
		#
		def count
			counter = 0
			Dir.glob("#{@path}/data/*.ree") do |f|
				counter += 1
			end
			return counter
		end

		# Little helper method to determine if a vault is in the middle of 
		# a write cycle. Which would cause horrible crashes on other applications
		# and errors on the file system if things are moved around inside
		#
		def locked?;
			@locked
		end

		def create(password = :failed)
			# If keygen was used to set a user password then fetch it
			# and remove the variable from memory!
			return nil unless password?(password)
			return nil unless encryption?(password)

			# puts "This is the password: #{password}"

			# => Encryption now active and key available under @crypt.key
			@conf_path = "#{@path}/config"

			needs_creation = true

			if self.includes?('config')
				raise VaultExistsAtLocationError.new, "Vault already exists at location #{@path}. Aborting operation..."

				# => This rules out lots of code to be run
				needs_creation = false
			else
				FileUtils::mkdir_p(File.expand_path("#{@path}/data")) # => Data dir
				FileUtils::mkdir(File.expand_path("#{@path}/shasums")) # => Checksum dir
				FileUtils::mkdir(File.expand_path("#{@path}/logs")) # => Logs dir

				# On *nix devices change permissions.
				if Reedb::archos == :linux || Reedb::archos == :osx || Reedb::archos == :vars
					FileUtils::chmod_R(0744, "#{@path}")
				end
			end

			# Now that the vault directory exists logs can be opened.
			init_logger(true)

			if needs_creation
				# Code that will only be run if the vault was just created on the system
				time = Reedb::Utilities.get_time(false)
				VaultLogger.write("Vault created on #{time}. All directories created successfully!")

				# => Now creating configuration file
				@config = {}
				@config['vault_name'] = "#{@name}"
				@config['creation_date'] = "#{Utilities.get_time}"
				@config['last_updated'] = "#{Utilities.get_time}"
				@config['creation_machine'] = "#{Socket.gethostname}"
				@config['updating_machine'] = "#{Socket.gethostname}"
				@config['creation_user'] = "#{Etc.getlogin}"
				@config['updating_user'] = "#{Etc.getlogin}"

				# Convert the header set to JSON, then write it into the config
				hset = JSON.dump(@header_set)
				@config['header_set'] = "#{hset}"

				# Add the Reedb version this vault was created with for upgradability
				@config['creation_version'] = "#{Reedb::VERSION}"
				save_config

				# Now writing encrypted key to file with ASCII armour
				update_secure_info('cey', @encrypted_key)
				# remove_instance_variable(:@encrypted_key)
			end
			self.load(password)
		end

		def load(password)
			unless self.includes?('config')
				raise VaultDoesNotExistError.new("Loading vault failed because it couldn't be found at the specified path!")
			end
			init_logger(false)

			# Check if the config needs to be read via ASCII64 or YAML
			if self.includes?('pom')
				# Config is stored with ASCII Armour
				@config = read_secure_info('config')
			else
				@config = YAML.load_file("#{@path}/config")
			end


			return nil unless unlock_vault("#{password}")
			VaultLogger.write('Finished loading vault', 'debug')
			cache_headers

			return self
		end

		# Read a single file from the vault in secure mode
		# Returns the entire file or only it's current set in hashes.
		#
		def read_file(name, history = false)

			# Loads the file data into a local variable if it exists
			file_data = load_file_data(name)
			if file_data == nil
				raise FileNotFoundError.new("#{name} could not be read: File not found!")
				# return VAULT_FILE_NOT_FOUND_ERROR # If the exception isn't handled correctly
			else
				# This code is executed if the file was found (thus data is in file_data)
				compiled = {}
				compiled['header'] = {}

				# Removes the latest version from the header because it is insignificant.
				file_data['header'].each do |key, value|
					compiled['header']["#{key}"] = value unless key == 'latest'
				end

				if history
					compiled['body'] = file_data['body']
				else
					body_list = []
					file_data['body'].each do |key, _|
						body_list << key
					end

					compiled['body'] = {}

					# Now sort the list of body versions
					body_list.heapsort!

					# Then compile the data together into one data hash
					body_list.each do |version|
						file_data['body']["#{version}"].each do |key, value|
							compiled['body']["#{key}"] = value
						end
					end
				end

				# Then return that hash. Huzza!
				return compiled
			end
		end

		# Check the file API or the wiki to learn how this function works.
		# This function is also used to delete fields from header space.
		#
		def update(name, data)

			# Cache headers first to be sure we're up to date
			cache_headers

			# Raises exception and [returns] in case exception isn't properly being handled
			(raise FileBusyError.new, "File #{name} busy"; return) if @locks.include?(name)
			@locks << name

			if @headers.key?(name)
				# Creates file object from existing file object.
				df = DataFile.new(name, self, load_file_data(name, :secure))
				df.insertv2(data, :hard) # Default cache mode
			else
				df = DataFile.new(name, self)
				df.insertv2(data, :hard) # Default cache mode
			end

			# => Make sure that everything is up to date.
			cache_headers
			@config['updating_user'] = "#{Etc.getlogin}"
			@config['updating_machine'] = "#{Socket.gethostname}"
			@config['last_updated'] = "#{Utilities.get_time}"
			@config['last_version'] = "#{Reedb::VERSION}"
			save_config

			# Sync and close the file.
			df.sync.close

			# Unlocks the file again for other processes to edit.
			@locks.delete(name)
		end

		def remove_file(name)
			path_to_file = load_file_hash(name)
			if path_to_file
				FileUtils.rm(path_to_file)
				VaultLogger.write("Removed file #{name} from vault.", 'debug')
			else
				raise FileNotFoundError.new("#{name} could not be removed: File not found!")
			end
		end

		# Returns headers according to a search queury
		#
		# { 'name' => '__name__',
		# 	'url' => '__url__',
		# 	'tags' => '__tags__',
		# 	'generic_field' => '__generic_information__'
		# }
		#
		# 'tags=search engines, internet#urls=www.poodle.com'
		#
		def list_headers search
			query = {}
			cache_headers # => This fills @headers and @hfields

			return @headers unless search

			begin
				splat = search.split('#')
				splat.each do |target|
					slice = target.split('=')
					query["#{slice[0]}"] = slice[1..-1]
				end

					# Rescue the query in case it was bad
			rescue
				raise MalformedSearchError.new, 'Malformed search data'
			end

			log_query = {}
			candidates = []

			query.each do |cat, data|
				data.each do |val|
					log_query["#{cat}"] = @hgroups["#{cat}"]["#{val}"] if @hgroups["#{cat}"].include?(val)
					log_query["#{cat}"].each { |c| candidates << c unless candidates.include?(c) }
				end
			end
			return_buffer = candidates
			candidates.each do |can|
				log_query.each do |cat, data|
					return_buffer.delete(can) unless log_query["#{cat}"].include?(can)
				end
			end

			return return_buffer
		end

		# Dump headers and files from memory in times of
		# inactivity for security reasons
		def unload(time)
			remove_instance_variable(:@headers)
			@headers = {}

			VaultLogger.write("It has been #{time*60} minutes since the last interaction. Unloading vault contents for security reasons.", 'debug')
		end

		def close
			VaultLogger.write('Force closing the vault. Check parent logs for details', 'debug')
			# puts "Crypto module is: #{@crypt}"
			@crypt.stop_encryption if @crypt && @crypt.init

			# Removing class variables for cleanup
			remove_instance_variable(:@crypt)
			remove_instance_variable(:@headers)
		end

		# Quickly returns if a file exists in the vault or it's children.
		def includes?(file)
			return File.exists?("#{@path}/#{file}")
		end

		def to_s
			return "Vault: #{@name}, Path: #{@path}, File count: #{@headers.length}"
		end

		private

		# Caches the current set of headers on a vault.
		# 
		def cache_headers
			@headers = {}

			VaultLogger.write('Starting a cache cycle.', 'debug')

			Dir.glob("#{@path}/data/*.ree") do |file|
				f = File.open(file, 'r')
				encrypted = Base64.decode64(f.read)
				decrypted = @crypt.decrypt(encrypted)

				raw = JSON.parse(decrypted)
				df = DataFile.new(nil, self, raw)

				tmp_head = df.cache(:header)
				tmp_name = df.name

				# Blank the df variable just in case.
				df = 0xEFFFFFFFFFFFFFFF
				# remove_instance_variable(df)

				@headers[tmp_name] = tmp_head

				# Now work with the header set to determine sub-groups
				tmp_head.each do |category, data|

					# This will loop through all the category groups in the
					# header that have been registered
					if @header_set.include?(category)

						# Creates a new sub-hash for data
						@hgroups["#{category}"] = {} unless @hgroups["#{category}"]

						if @header_set["#{category}"] == 'list'
							data.each do |target|
								@hgroups["#{category}"]["#{target}"] = [] unless @hgroups["#{category}"]["#{target}"]
								@hgroups["#{category}"]["#{target}"] << tmp_name unless @hgroups["#{category}"]["#{target}"].include?(tmp_name)
							end

						elsif @header_set["#{category}"] == 'single'
							@hgroups["#{category}"] = "#{data}"
						end

						#TODO: Implement dictionary head later
					end
				end
			end
		end

		def load_file_hash name
			cache_headers
			if @headers.key?(name)
				name_hash = SecurityUtils::tiger_hash("#{name}")
				return "#{@path}/data/#{name_hash}.ree"
			else
				return false
			end
		end

		# Loads a file with the clear name from headers.
		# If file isn't found in headers vault is recached
		# and file is then loaded from headers.
		#
		# If file isn't found in headers error is output.
		#
		def load_file_data(name, mode = :secure)
			cache_headers
			VaultLogger.write("Loading file #{name} from vault", 'debug')
			if @headers.key?(name)
				name_hash = SecurityUtils::tiger_hash("#{name}")
				file_path = "#{@path}/data/#{name_hash}.ree"
				f = File.open(file_path, 'r')
				encrypted = Base64.decode64(f.read)
				decrypted = @crypt.decrypt(encrypted)

				return JSON.parse(decrypted) if mode == :secure
			else
				return nil
			end
		end

		def save_config
			@conf_path = "#{@path}/config"
			if @secure_config
				update_secure_info('config', @config)
				par_path = "#{@path}/pom"
				msg = 'Polarbears are left handed. Spread the word!'
				File.open("#{par_path}", 'wb').write(Base64.encode64("#{msg}"))
			else
				File.open("#{@conf_path}", 'wb+') { |f| YAML.dump(@config, f) }
			end
		end

		# Builds the vault path from a path, name and trimming
		# additional slashes from the end.
		#
		def construct_path(name, path)
			(@name = name; @path = '')
			path.end_with?('/') ? @path = "#{path}#{name}.reevault" : @path = "#{path}/#{name}.reevault"
		end

		def update_secure_info(name, data = nil)
			path = "#{@path}/#{name}"
			File.write(path, Base64.encode64(data))
			# File.open(path, 'wb+').write(Base64.encode64(data))
		end

		def read_secure_info(name)
			path = "#{@path}/#{name}"
			return Base64.decode64(File.read(path))
			# return Base64.decode64(File.open(path, 'r').read())
		end

		def init_logger(bool)
			begin
				unless logger?(bool)
					raise VaultLoggerError.new, 'Logger failed to be initialised'
				end
			rescue VaultError => e
				puts e.message
			end
		end

		def logger? bool
			(return false) if @already_logging && bool

			VaultLogger.setup("#{@path}")
			(@already_logging = true; return true)
		end

		def password?(password)
			raise MissingUserPasswordError.new, 'Encryption error: Missing user password!' if password == nil
			raise InsecureUserPasswordError.new, 'Encryption error: Password too short! See: https://xkcd.com/936/' if password.length < Reedb::passlength
			return true
		end

		def encryption?(password)
			begin
				@encrypted_key = @crypt.start_encryption(password)
			rescue EncryptionError => e
				puts e.message
				return false
			end
			return true
		end

		# Unlocks the vault by decrypting the key and loading it into memory
		# Enables the cryptographic module to decrypt and encrypt files.
		#
		def unlock_vault(pw)
			begin
				@encrypted_key = read_secure_info('cey') unless @encrypted_key
				@crypt.start_encryption(pw, @encrypted_key)
				remove_instance_variable(:@encrypted_key) if @encrypted_key
			rescue Exception => e
				puts e.class # TODO: This finds out the class of the exception next time it is encountered c:
				raise WrongUserPasswordError.new, 'Incorrect user passphrase. Could not unlock!'
			end

			# Return values for the rest of the file.
			return @crypt.init
		end

		# This method checks what encryption to use by enums.
		# This can throw an exception if something was parsed incorrectly
		# After this call the @crypt object has been initialised.
		#
		def init_encryption type
			type = :aes if type == :auto
			if type == :aes
				@crypt = Reedb::RAES.new
			elsif type == :twofish
				@crypt = Reedb::Fish.new
			elsif type == :multi
				@crypt = Reedb::MLE.new
			else
				raise MissingEncryptionTypeError.new, "Encryption failed: Missing type. Aborting..."
			end
		end

	end # class close
end # module close
