# frozen_string_literal: true
module ElasticRubyServer
  class Events
    def initialize(global_synchronization)
      @host_project_roots = ENV.fetch("HOST_PROJECT_ROOTS")
      @project_root = ENV.fetch("PROJECTS_ROOT")
      @global_synchronization = global_synchronization
      @local_synchronization = Concurrent::FixedThreadPool.new(3)
    end

    def on_initialize(params) # params: {"processId"=>54359, "clientInfo"=>{"name"=>"Visual Studio Code", "version"=>"1.56.2"}, "locale"=>"en-us", "rootPath"=>"/Users/joelkorpela/clio/themis/test", "rootUri"=>"file:///Users/joelkorpela/clio/themis/test", "capabilities"=>{"workspace"=>{"applyEdit"=>true, "workspaceEdit"=>{"documentChanges"=>true, "resourceOperations"=>["create", "rename", "delete"], "failureHandling"=>"textOnlyTransactional", "normalizesLineEndings"=>true, "changeAnnotationSupport"=>{"groupsOnLabel"=>true}}, "didChangeConfiguration"=>{"dynamicRegistration"=>true}, "didChangeWatchedFiles"=>{"dynamicRegistration"=>true}, "symbol"=>{"dynamicRegistration"=>true, "symbolKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]}, "tagSupport"=>{"valueSet"=>[1]}}, "codeLens"=>{"refreshSupport"=>true}, "executeCommand"=>{"dynamicRegistration"=>true}, "configuration"=>true, "workspaceFolders"=>true, "semanticTokens"=>{"refreshSupport"=>true}, "fileOperations"=>{"dynamicRegistration"=>true, "didCreate"=>true, "didRename"=>true, "didDelete"=>true, "willCreate"=>true, "willRename"=>true, "willDelete"=>true}}, "textDocument"=>{"publishDiagnostics"=>{"relatedInformation"=>true, "versionSupport"=>false, "tagSupport"=>{"valueSet"=>[1, 2]}, "codeDescriptionSupport"=>true, "dataSupport"=>true}, "synchronization"=>{"dynamicRegistration"=>true, "willSave"=>true, "willSaveWaitUntil"=>true, "didSave"=>true}, "completion"=>{"dynamicRegistration"=>true, "contextSupport"=>true, "completionItem"=>{"snippetSupport"=>true, "commitCharactersSupport"=>true, "documentationFormat"=>["markdown", "plaintext"], "deprecatedSupport"=>true, "preselectSupport"=>true, "tagSupport"=>{"valueSet"=>[1]}, "insertReplaceSupport"=>true, "resolveSupport"=>{"properties"=>["documentation", "detail", "additionalTextEdits"]}, "insertTextModeSupport"=>{"valueSet"=>[1, 2]}}, "completionItemKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]}}, "hover"=>{"dynamicRegistration"=>true, "contentFormat"=>["markdown", "plaintext"]}, "signatureHelp"=>{"dynamicRegistration"=>true, "signatureInformation"=>{"documentationFormat"=>["markdown", "plaintext"], "parameterInformation"=>{"labelOffsetSupport"=>true}, "activeParameterSupport"=>true}, "contextSupport"=>true}, "definition"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "references"=>{"dynamicRegistration"=>true}, "documentHighlight"=>{"dynamicRegistration"=>true}, "documentSymbol"=>{"dynamicRegistration"=>true, "symbolKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]}, "hierarchicalDocumentSymbolSupport"=>true, "tagSupport"=>{"valueSet"=>[1]}, "labelSupport"=>true}, "codeAction"=>{"dynamicRegistration"=>true, "isPreferredSupport"=>true, "disabledSupport"=>true, "dataSupport"=>true, "resolveSupport"=>{"properties"=>["edit"]}, "codeActionLiteralSupport"=>{"codeActionKind"=>{"valueSet"=>["", "quickfix", "refactor", "refactor.extract", "refactor.inline", "refactor.rewrite", "source", "source.organizeImports"]}}, "honorsChangeAnnotations"=>false}, "codeLens"=>{"dynamicRegistration"=>true}, "formatting"=>{"dynamicRegistration"=>true}, "rangeFormatting"=>{"dynamicRegistration"=>true}, "onTypeFormatting"=>{"dynamicRegistration"=>true}, "rename"=>{"dynamicRegistration"=>true, "prepareSupport"=>true, "prepareSupportDefaultBehavior"=>1, "honorsChangeAnnotations"=>true}, "documentLink"=>{"dynamicRegistration"=>true, "tooltipSupport"=>true}, "typeDefinition"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "implementation"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "colorProvider"=>{"dynamicRegistration"=>true}, "foldingRange"=>{"dynamicRegistration"=>true, "rangeLimit"=>5000, "lineFoldingOnly"=>true}, "declaration"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "selectionRange"=>{"dynamicRegistration"=>true}, "callHierarchy"=>{"dynamicRegistration"=>true}, "semanticTokens"=>{"dynamicRegistration"=>true, "tokenTypes"=>["namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string", "number", "regexp", "operator"], "tokenModifiers"=>["declaration", "definition", "readonly", "static", "deprecated", "abstract", "async", "modification", "documentation", "defaultLibrary"], "formats"=>["relative"], "requests"=>{"range"=>true, "full"=>{"delta"=>true}}, "multilineTokenSupport"=>false, "overlappingTokenSupport"=>false}, "linkedEditingRange"=>{"dynamicRegistration"=>true}}, "window"=>{"showMessage"=>{"messageActionItem"=>{"additionalPropertiesSupport"=>true}}, "showDocument"=>{"support"=>true}, "workDoneProgress"=>true}, "general"=>{"regularExpressions"=>{"engine"=>"ECMAScript", "version"=>"ES2020"}, "markdown"=>{"parser"=>"marked", "version"=>"1.1.0"}}}, "trace"=>"off", "workspaceFolders"=>[{"uri"=>"file:///Users/joelkorpela/clio/themis/test", "name"=>"test"}]}
      @host_workspace_path = params["rootPath"]

      raise("host_project_root not found") unless host_project_root

      index_name = elasticsearch_index_name(@host_workspace_path)
      project_name = find_name(host_project_root)

      @container_workspace_path = @host_workspace_path.sub(host_project_root, "#{@project_root}#{project_name}")
      @search = Search.new(@host_workspace_path, index_name)
      @persistence = Persistence.new(@host_workspace_path, @container_workspace_path, index_name)

      Server::Capabilities
    end

    def on_initialized(_hash)
      Log.debug(`/app/exe/es_check.sh`)

      @local_synchronization.post do
        @persistence.index_all(preserve: true)
      rescue => e
        Log.debug("Error in thread:")
        Log.debug(e)
      end
    end

    def on_textDocument_didSave(params) # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/test/testing.rb"}}
      @local_synchronization.post do
        uri = params["textDocument"]["uri"]
        file_path = strip_protocol(uri)

        @persistence.reindex(file_path)
      rescue => e
        Log.debug("Error in thread:")
        Log.debug(e)
      end
    end

    def on_textDocument_didChange(params) # {"textDocument":{"uri":"file:///Users/joelkorpela/clio/themis/test/testing.rb","version":26},"contentChanges":[{"text":"module NarWan\n class LetsGo\n before_action :another_method\n\n def self.a_method\n end\n\n def a_method(args)\n args\n end\n\n def another_method\n a_method\n end\n\n def new_method2\n\n end\n\n def new_method4\n\n end\n\n def new_method3\n\n end\n\n def new_method\n\n end\n\n def supported_method\n new_method\n new_method2\n new_method3\n new_method4\n\n local_var = \"value\"\n @nar = 'nar'\n @@bla = 'bla'\n\n local_\n\n local_var\n @nar\n @@bla\n end\n\n def create\n # {\"_index\"=>\"ruby_parser_index\", \"_type\"=>\"_doc\", \"_id\"=>\"E6vDB3oBjMXYsUxkfdEL\", \"_score\"=>15.857785, \"_source\"=>{\"scope\"=>[\"Manage\", \"Api\", \"V4\", \"SearchController\", \"index\", \"models_with_highlights\"], \"file_path\"=>\"/components/manage/app/controllers/manage/api/v4/search_controller.rb\", \"name\"=>\"filter\", \"line\"=>50, \"type\"=>\"send\", \"category\"=>\"usage\", \"columns\"=>{\"gte\"=>33, \"lte\"=>70}}},\n # {\"_index\"=>\"ruby_parser_index\", \"_type\"=>\"_doc\", \"_id\"=>\"FKvDB3oBjMXYsUxkfdEL\", \"_score\"=>15.857785, \"_source\"=>{\"scope\"=>[\"Manage\", \"Api\", \"V4\", \"SearchController\", \"index\", \"models_with_highlights\"], \"file_path\"=>\"/components/manage/app/controllers/manage/api/v4/search_controller.rb\", \"name\"=>\"parse_model_fields\", \"line\"=>50, \"type\"=>\"send\", \"category\"=>\"usage\", \"columns\"=>{\"gte\"=>33, \"lte\"=>63}}}\n a_method.another_method\n end\n end\nend\n\nNarWan::LetsGo\nNarWan::LetsGo.a_method\nNarWan::LetsGo.new.another_method\n\nmodule NarTwo\n module Nesting\n end\nend\n\nNarTwo::NewConstant = :value\nNarTwo::NewConstant\n\nmodule NarTwo::Nesting::FinalNest\n def nested_method\n end\nend\n\nmodule Foo\n class Bar\n class AnError < StandardError; end\n\n Constant = AnError\n end\nend\n"}]}
      Log.debug("on_textDocument_didChange:")
      Log.debug(params)

      @local_synchronization.post do
        uri = params["textDocument"]["uri"]
        file_path = strip_protocol(uri)
        changes = params["contentChanges"]

        Log.debug("received #{changes.count} changes:")
        Log.debug(changes)

        @persistence.reindex(file_path, content: { file_path => changes.first["text"] })
      rescue => e
        Log.debug("Error in thread:")
        Log.debug(e)
      end
    end

    def on_workspace_reindex(params)
      @local_synchronization.post do
        Log.debug("on_workspace_reindex: #{params}")
        @persistence.index_all(preserve: false)
      rescue => e
        Log.debug("Error in thread:")
        Log.debug(e)
      end
    end

    def on_workspace_didChangeWatchedFiles(params) # {"changes"=>[{"uri"=>"file:///Users/joelkorpela/clio/themis/components/foundations/extensions/rack_session_id.rb", "type"=>3}, {"uri"=>"file:///Users/joelkorpela/clio/themis/components/foundations/app/services/foundations/lock.rb", "type"=>3}, ...
      @global_synchronization.post do
        file_paths = strip_protocols(params["changes"])
        @persistence.reindex(*file_paths)
      rescue => e
        Log.debug("Error in thread:")
        Log.debug(e)
      end
    end

    def on_textDocument_definition(params) # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/test/testing.rb"}, "position"=>{"line"=>19, "character"=>16}}
      uri = params["textDocument"]["uri"]
      file_path = strip_protocol(uri)

      @search.find_definitions(file_path, params["position"])
    end

    def on_workspace_symbol(params) # {"query"=>"abc"}
      @search.find_symbols(params["query"])
    end

    private

    def host_project_root
      @host_project_roots
        .split(",")
        .map { |path| path.delete("\"") } # Strange, not sure why these slashes are being added
        .keep_if { |path| @host_workspace_path.match?(path) }
        .sort_by(&:length)
        .last
    end

    def find_name(dir_path)
      dir_path.match(/\/([^\/]*?)(\/$|$)/)[1] # match the last directory in the path
    end

    def elasticsearch_index_name(path)
      Digest::SHA1.hexdigest(path)
    end

    def strip_protocols(changes)
      changes.map do |change|
        strip_protocol(change["uri"])
      end
    end

    def strip_protocol(uri)
      uri[7..-1]
    end
  end
end
