module Metanorma
  class Compile
    def install_fonts(options)
      return unless validate_install_fonts(options)

      @updated_formulas_repo = false
      manifest = @processor.fonts_manifest
      agree_to_terms = options[:agree_to_terms] || false
      continue_without_fonts = options[:continue_without_fonts] || false
      no_progress = options[:no_progress] || false
      install_fonts_safe(manifest, agree_to_terms, continue_without_fonts,
                         no_progress)
    end

    private

    def validate_install_fonts(options)
      if options[:no_install_fonts]
        Util.log("[fontist] Skip font installation because" \
                 " --no-install-fonts argument passed", :debug)
        return false
      elsif missing_fontist_manifest?
        Util.log("[fontist] Skip font installation because "\
                 "font_manifest is missing", :debug)
        return false
      end
      true
    end

    def install_fonts_safe(manifest, agree, continue, no_progress)
      fontist_install(manifest, agree, no_progress)
    rescue Fontist::Errors::LicensingError
      if continue
        Util.log(
          "[fontist] Processing will continue without fonts installed",
          :debug
        )
      else
        Util.log("[fontist] Aborting without proper fonts installed," \
                 " make sure that you have set option --agree-to-terms", :fatal)
      end
    rescue Fontist::Errors::FontError => e
      log_level = continue ? :warning : :fatal
      Util.log("[fontist] '#{e.font}' font is not supported. " \
               "Please report this issue at github.com/metanorma/metanorma-"\
               "#{@processor.short}/issues to report this issue.", log_level)
    rescue Fontist::Errors::FormulaIndexNotFoundError
      if @updated_formulas_repo
        Util.log(
          "[fontist] Bug: formula index not found after 'fontist update'",
          :fatal
        )
      end
      Util.log("[fontist] Missing formula index. Fetching it...", :debug)
      Fontist::Formula.update_formulas_repo
      @updated_formulas_repo = true
      install_fonts_safe(manifest, agree, continue, no_progress)
    end

    def fontist_install(manifest, agree, no_progress)
      Fontist::Manifest::Install.from_hash(
        manifest,
        confirmation: agree ? "yes" : "no",
        no_progress: no_progress
      )
    end

    def fontist_font_locations(options)
      return nil if missing_fontist_manifest? || options[:no_install_fonts]

      dump_fontist_manifest_locations(@processor.fonts_manifest)
    rescue Fontist::Errors::FormulaIndexNotFoundError
      raise unless options[:continue_without_fonts]

      nil
    end

    def dump_fontist_manifest_locations(manifest)
      location_manifest = Fontist::Manifest::Locations.from_hash(
        manifest
      )
      location_manifest_file = Tempfile.new(["fontist_locations", ".yml"])
      location_manifest_file.write location_manifest.to_yaml
      location_manifest_file.flush
      location_manifest_file
    end

    def missing_fontist_manifest?
      !@processor.respond_to?(:fonts_manifest) || @processor.fonts_manifest.nil?
    end
  end
end
