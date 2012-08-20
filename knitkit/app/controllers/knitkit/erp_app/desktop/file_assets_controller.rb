module Knitkit
  module ErpApp
    module Desktop
      class FileAssetsController < ::ErpApp::Desktop::FileManager::BaseController
        skip_before_filter :verify_authenticity_token, :only => :upload_file
        skip_before_filter :require_login, :only => [:download_file_asset]
        before_filter :set_asset_model
        before_filter :set_root_node

        def base_path          
          if @root_node.nil?
            @base_path = nil
          else
            @base_path = File.join(@file_support.root, @root_node) 
          end

          @base_path
        end

        def expand_directory
          if @assets_model.nil?
            render :json => []
          else
            path = (params[:node] == ROOT_NODE) ? base_path : params[:node]
            render :json => @file_support.build_tree(path, :file_asset_holder => @assets_model, :preload => true)
          end
        end

        def create_file
          path = params[:path] == 'root_node' ? base_path : params[:path]
          name = params[:name]

          @assets_model.add_file('#Empty File', File.join(path, name))

          render :json => {:success => true}
        end

        def create_folder
          path = (params[:path] == 'root_node') ? base_path : params[:path]
          name = params[:name]

          path = File.join(@file_support.root,path) if path.index(@file_support.root).nil?

          @file_support.create_folder(path, name)
          render :json => {:success => true}
        end

        def upload_file
          #Website level assets if allowed to be viewed can also be uploaded and deleted so this is only checking for the view capability
          if @context == Website
            capability_type = "view"
            capability_resource = "SiteFileAsset"
          else
            capability_type = "upload"
            capability_resource = "GlobalFileAsset"
          end

          model = DesktopApplication.find_by_internal_identifier('knitkit')
          begin
            current_user.with_capability(model, capability_type, capability_resource) do
              result = {}
              upload_path = params[:directory]
              name = params[:name]
              data = request.raw_post

              begin
                upload_path == 'root_node' ? @assets_model.add_file(data, File.join(@file_support.root,base_path,name)) : @assets_model.add_file(data, File.join(@file_support.root,upload_path,name))
                result = {:success => true}
              rescue Exception=>ex
                logger.error ex.message
                logger.error ex.backtrace.join("\n")
                result = {:success => false, :error => "Error uploading file."}
              end

              #the awesome uploader widget whats this to mime type text, leave it render :inline
              render :inline => result.to_json
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability=>ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def save_move
          messages = []
          result = {}
          path = params[:node]
          new_parent_path = params[:parent_node]
          new_parent_path = @root_node if new_parent_path == ROOT_NODE
          
          nodes_to_move = (params[:selected_nodes] ? JSON(params[:selected_nodes]) : [params[:node]])
          begin
            nodes_to_move.each do |path|
              if ErpTechSvcs::Config.file_storage == :filesystem and !File.exists?(File.join(@file_support.root, path))
                result = {:success => false, :msg => 'File does not exist.'}
              else
                file = @assets_model.files.find(:first, :conditions => ['name = ? and directory = ?', ::File.basename(path), ::File.dirname(path)])
                result, message = file.move(new_parent_path)
              end
              messages << message
            end
            render :json => {:success => true, :msg => messages.join(',')}
          rescue Exception => e
           render :json => {:success => false, :msg => e.message}
          end
        end

        def delete_file
          messages = []

          if @context == Website
            capability_type = "view"
            capability_resource = "SiteFileAsset"
          else
            capability_type = "delete"
            capability_resource = "GlobalFileAsset"
          end

          nodes_to_delete = (params[:selected_nodes] ? JSON(params[:selected_nodes]) : [params[:node]])

          model = DesktopApplication.find_by_internal_identifier('knitkit')
          begin
            result = false
            nodes_to_delete.each do |path|
              current_user.with_capability(model, capability_type, capability_resource) do
                path = "#{path}/" if params[:leaf] == 'false' and path.match(/\/$/).nil?                
                begin
                  name = File.basename(path)
                  result, message, is_folder = @file_support.delete_file(File.join(@file_support.root,path))
                  if result and !is_folder
                    file = @assets_model.files.find(:first, :conditions => ['name = ? and directory = ?', ::File.basename(path), ::File.dirname(path)])
                    file.destroy
                  end
                  messages << message
                rescue Exception=>ex
                  Rails.logger.error ex.message
                  Rails.logger.error ex.backtrace.join("\n")
                  render :json => {:success => false, :error => "Error deleting #{name}"} and return
                end
              end # end current_user.with_capability
            end # end nodes_to_delete.each
            if result
              render :json => {:success => true, :message => messages.join(',')}
            else
              render :json => {:success => false, :error => messages.join(',')}
            end
          rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability=>ex
            render :json => {:success => false, :message => ex.message}
          end
        end

        def rename_file
          path = params[:node]
          name = params[:file_name]

          result, message = @file_support.rename_file(File.join(@file_support.root,path), name)
          if result
            file = @assets_model.files.find(:first, :conditions => ['name = ? and directory = ?', ::File.basename(path), ::File.dirname(path)])
            file.name = name
            file.save
          end

          render :json =>  {:success => true, :message => message}
        end

        def update_security
          path   = params[:path]
          secure = params[:secure]
          roles  = ['admin', 'file_downloader']
          
          file = @assets_model.files.find(:first, :conditions => ['name = ? and directory = ?', ::File.basename(path), ::File.dirname(path)])
          roles << @assets_model.website_role_iid if @context == :website
          
          (secure == 'true') ? file.add_capability(:download, nil, roles) : file.remove_all_capabilities

          # if we're using S3, set file permissions to private or public_read   
          @file_support.set_permissions(path, ((secure == 'true') ? :private : :public_read)) if Rails.application.config.erp_tech_svcs.file_storage == :s3
          
          render :json =>  {:success => true}
        end

        # DEPRECATED, use erp_app/public#download
        def download_file_asset
          path = params[:path]

          file = @assets_model.files.find(:first, :conditions => ['name = ? and directory = ?', ::File.basename(path), ::File.dirname(path)])
          if(file.has_capabilities?)
            begin
              unless current_user == false
                current_user.with_capability(file, :download, nil) do
                  redirect_to file.data.url
                end
              else
                raise ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability
              end
            rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability=>ex
              render :text => ex.message
            rescue Exception=>ex
              render :text => "User does not have capability."
            end
          else
            redirect_to file.data.url
          end
        end

        protected

        def set_file_support
          @file_support = ErpTechSvcs::FileSupport::Base.new(:storage => Rails.application.config.erp_tech_svcs.file_storage)
        end

        def set_root_node
          @root_node = nil

          if @context == :website
            @root_node = File.join(Rails.application.config.erp_tech_svcs.file_assets_location,"sites",@assets_model.iid) unless @assets_model.nil?
          else
            @root_node = File.join(Rails.application.config.erp_tech_svcs.file_assets_location,"shared_site_files")
          end

          @root_node
        end

        def set_asset_model
          @context = params[:context].to_sym

          if @context == :website
            website_id = params[:website_id]
            (@assets_model = website_id.blank? ? nil : Website.find(website_id))

            render :inline => {:success => false, :error => "No Website Selected"}.to_json if (@assets_model.nil? && params[:action] != "base_path")
          else
            @assets_model = CompassAeInstance.first
          end
        end
  
      end#FileAssetsController
    end#Desktop
  end#ErpApp
end#Knitkit
