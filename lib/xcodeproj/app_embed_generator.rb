require_relative '../utils/ruby_2_0_monkeypatches'

module StructCore
	class AppEmbedGenerator
		def initialize
			@target_map = {}
			@embeddable_target_map = {}
			@target_native_map = {}
		end

		# @param spec [Specfile]
		def preprocess(spec)
			target_map = spec.targets.map { |target|
				[target.name, target]
			}.to_h

			spec.targets.map { |target|
				embedded_targets = target.references.select { |ref|
					ref.is_a?(Specfile::Target::TargetReference)
				}.map { |ref|
					target_map[ref.target_name]
				}.select { |ref_target|
					ref_target.configurations[0].profiles.include?('watchkit2-extension') ||
						ref_target.configurations[0].profiles.include?('application.watchapp2')
				}

				@target_map[target.name] = embedded_targets
				embedded_targets.each { |et|
					if @embeddable_target_map.key? et.name
						@embeddable_target_map[et.name] << target
					else
						@embeddable_target_map[et.name] = [target]
					end

				}
			}
		end

		def register(target, native_target)
			@target_native_map[target.name] = native_target
		end

		def embed(project)
			@target_map.each { |target_name, embedded_targets|
				embed_watch_content_phase = nil
				embed_app_extensions_phase = nil

				native_target = @target_native_map[target_name]
				next if native_target.nil?

				embedded_native_targets = embedded_targets.map { |et| [et, @target_native_map[et.name]] }
				next if embedded_native_targets.count != embedded_targets.count

				embedded_native_targets.each { |pair|
					embedded_target, embedded_native_target = pair

					if embedded_target.configurations[0].profiles.include? 'application.watchapp2'
						embed_watch_content_phase ||= project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
						embed_watch_content_phase.name = 'Embed Watch Content'
						embed_watch_content_phase.dst_subfolder_spec = '16'
						embed_watch_content_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'

						embed_watch_content_phase.add_file_reference embedded_native_target.product_reference
					elsif embedded_target.configurations[0].profiles.include? 'watchkit2-extension'
						embed_app_extensions_phase ||= project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
						embed_app_extensions_phase.name = 'Embed App Extensions'
						embed_app_extensions_phase.symbol_dst_subfolder_spec = :plug_ins

						embed_app_extensions_phase.add_file_reference embedded_native_target.product_reference
					end
				}

				native_target.build_phases.insert(native_target.build_phases.count, embed_watch_content_phase) unless embed_watch_content_phase.nil?
				native_target.build_phases.insert(native_target.build_phases.count, embed_app_extensions_phase) unless embed_app_extensions_phase.nil?
			}
		end
	end
end