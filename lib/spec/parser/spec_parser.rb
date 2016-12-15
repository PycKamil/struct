require_relative 'spec_parser_1_0_X'

module Xcodegen
	class Specparser
		def initialize
			@parsers = []
		end

		def register(parser)
			if parser.respond_to?(:parse) && parser.respond_to?(:can_parse_version)
				@parsers << parser
			else
				raise StandardError.new 'Unsupported parser object. Parser object must support :parse and :can_parse_version'
			end
		end

		def register_defaults
			@parsers.unshift *[
				Xcodegen::Specparser10X.new
			]
		end

		# @param path [String]
		def parse(path)
			if @parsers.length == 0
				register_defaults
			end

			filename = (Pathname.new(path)).absolute? ? path : File.join(Dir.pwd, path)
			raise StandardError.new "Error: Spec file #{filename} does not exist" unless File.exist? filename

			if filename.end_with? 'yml' or filename.end_with? 'yaml'
				spec_hash = YAML.load_file filename
			elsif filename.end_with? 'json'
				spec_hash = JSON.parse File.read(filename)
			else
				raise StandardError.new 'Error: Unable to determine file format of project file'
			end

			raise StandardError.new "Error: Invalid spec file. No 'version' key was present." unless spec_hash != nil and spec_hash.key? 'version'

			begin
				spec_version = Semantic::Version.new spec_hash['version']
			rescue StandardError => _
				raise StandardError.new 'Error: Invalid spec file. Project version is invalid.'
			end

			parser = @parsers.find { |parser|
				parser.can_parse_version(spec_version)
			}

			raise StandardError.new "Error: Invalid spec file. Project version #{spec_hash['version']} is unsupported by this version of xcodegen." unless parser != nil

			raise StandardError.new "Error: Invalid spec file. No 'configurations' key was present." unless spec_hash.key? 'configurations'
			raise StandardError.new "Error: Invalid spec file. Key 'configurations' should be a hash" unless spec_hash['configurations'].is_a?(Hash)
			raise StandardError.new 'Error: Invalid spec file. Project should have at least one configuration' unless spec_hash['configurations'].keys.count > 0

			parser.parse(spec_version, spec_hash, filename)
		end

	end
end