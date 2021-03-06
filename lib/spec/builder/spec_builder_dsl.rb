require 'semantic'
require_relative 'spec_builder_12X/spec_file_dsl_12X'
require_relative 'spec_builder_13X/spec_file_dsl_13X'

module StructCore
	class SpecBuilderDsl
		def initialize(spec_file, file_dsls = [])
			@spec_file = spec_file
			@file_dsls = file_dsls
			@project_base_dir = nil
			@current_scope = nil

			register_defaults if @file_dsls.empty?
		end

		attr_accessor :project_base_dir

		def register(dsl)
			if dsl.respond_to?(:supports_version)
				@file_dsls << dsl
				return
			end

			raise StandardError.new 'Unsupported DSL object. DSL object must support :supports_version'
		end

		def register_defaults
			@file_dsls.unshift(
				StructCore::SpecFileDSL12X.new,
				StructCore::SpecFileDSL13X.new
			)
		end

		def build
			@spec_file
		end

		def spec(version, &block)
			begin
				spec_version = Semantic::Version.new version
			rescue StandardError => _
				raise StandardError.new 'Error: Invalid spec file. Project version is invalid.'
			end

			dsl = @file_dsls.find { |dsl|
				dsl.supports_version(spec_version)
			}

			raise StandardError.new "Error: Invalid spec file. Project version #{version} is unsupported by this version of struct." if dsl.nil?

			@spec_file.version = spec_version
			dsl.spec_file = @spec_file
			dsl.project_base_dir = @project_base_dir

			@current_scope = dsl
			block.call
			@current_scope = nil
		end

		def respond_to_missing?(_, _)
			!@current_scope.nil?
		end

		def method_missing(method, *args, &block)
			@current_scope.send(method, *args, &block)
		end
	end
end