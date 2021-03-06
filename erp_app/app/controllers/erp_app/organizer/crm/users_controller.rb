module ErpApp
  module Organizer
    module Crm
      class UsersController < ErpApp::Organizer::BaseController

        def index
          party_role = params[:party_role]
          to_role = params[:to_role]
          to_party_id = params[:to_party_id]
          offset = params[:start] || 0
          limit = params[:limit] || 25
          included_party_to_relationships = ActiveSupport::JSON.decode params[:included_party_to_relationships]
          query_filter = params[:query_filter] || nil

          user_table = User.arel_table

          statement = User.joins(:party => :party_roles).where(:party_roles => {:role_type_id => RoleType.iid(party_role).id})

          unless to_role.blank?
            to_role_type = RoleType.iid(to_role)

            if to_party_id.blank?
              to_party = current_user.party
              to_party_rln = to_party.from_relationships.where('role_type_id_to = ?', to_role_type).first

              unless to_party_rln.nil?
                statement = statement.joins("join party_relationships on party_relationships.party_id_from = parties.id")
                .where('party_relationships.party_id_to = ?', to_party_rln.party_id_to)
                .where('party_relationships.role_type_id_to' => to_role_type)
              end
            else
              to_party = Party.find(to_party_id)

              statement = statement.joins("join party_relationships on party_relationships.party_id_from = parties.id")
              .where('party_relationships.party_id_to = ?', to_party.id)
              .where('party_relationships.role_type_id_to' => to_role_type)
            end
          end

          if query_filter
            statement = statement.where(user_table[:username].matches("%#{query_filter}%")
                                        .or(user_table[:email].matches("%#{query_filter}%")))
          end

          total = statement.uniq.count
          users = statement.uniq.limit(limit).offset(offset).all

          data = {
              :success => true,
                  :users => users.collect do |user|
                    user_data = user.to_hash(:only =>
                                                 [:id, :username,
                                                  :email,
                                                  :last_login_at,
                                                  :created_at,
                                                  :updated_at,
                                                  :activation_state],
                                             :party_description => (user.party.description))

                    # add relationships
                    included_party_to_relationships.each do |included_party_to_relationship|
                      included_party_to_relationship.symbolize_keys!

                      relationship = user.party.relationships.where('relationship_type_id = ?', RelationshipType.find_by_internal_identifier(included_party_to_relationship[:relationshipType])).first
                      if relationship
                        user_data[included_party_to_relationship[:toRoleType]] = relationship.to_party.description
                      end
                    end

                    if user.party.business_party.class == Individual
                      user_data[:first_name] = user.party.business_party.current_first_name
                      user_data[:last_name] = user.party.business_party.current_last_name
                    end

                    user_data
                  end,
                  :total => total
          }

          render :json => data
        end

        def show
          result = {:success => true}

          user = User.where('id = ?', params[:id]).first

          if user
            result[:user] = user.to_hash(:only =>
                                             [:id,
                                              :username,
                                              :email,
                                              :last_login_at,
                                              :created_at,
                                              :updated_at,
                                              :activation_state])
          end

          render :json => result
        end

        def create
          result = {}

          user_data = params[:data].present? ? params[:data] : params
          party_id = params[:party_id] || user_data[:party_id]

          party = Party.find(party_id)

          begin
            ActiveRecord::Base.transaction do
              user = User.new(
                  :email => user_data['email'].strip,
                  :username => user_data['username'].strip,
              )

              if user_data[:password].present? && user_data[:password_confirmation].present?
                user.password = user_data[:password].strip
                user.password_confirmation = user_data[:password_confirmation].strip
                user.add_instance_attribute(:temp_password, user_data[:password])
              else
                temp_password = 'AB' + SecureRandom.uuid[0..5] + 'CD'
                user.password = temp_password
                user.password_confirmation = temp_password
                user.add_instance_attribute(:temp_password, temp_password)
              end

              #set this to tell activation where to redirect_to for login and temp password
              user.add_instance_attribute(:login_url, '/erp_app/login')

              user.party = party

              if user.save
                result = {:success => user.save, :users => user.to_hash(:only =>
                                                                            [:id, :username,
                                                                             :email,
                                                                             :last_login_at,
                                                                             :created_at,
                                                                             :updated_at,
                                                                             :activation_state])}
              else
                result = {:success => false, :message => user.errors.full_messages.to_sentence}
              end
            end
          rescue Exception => ex
            Rails.logger.error ex.message
            Rails.logger.error ex.backtrace.join("\n")

            result = {:success => false, :message => "Error adding user."}
          end

          render :json => result
        end

        def update
          user_data = params[:data].present? ? params[:data] : params

          user = User.find(params[:id])

          user.username = user_data[:username].strip
          user.email = user_data[:email].strip

          if user_data[:activation_state].present? && user_data[:activation_state] != 'pending'
            user.activation_state = user_data[:activation_state].strip
          end

          if user_data[:password].present? && user_data[:password_confirmation].present?
            user.password = user_data[:password].strip
            user.password_confirmation = user_data[:password_confirmation].strip
          end

          if user.save
            result = {:success => user.save, :users => user.to_hash(:only =>
                                                                        [:id, :username,
                                                                         :email,
                                                                         :last_login_at,
                                                                         :created_at,
                                                                         :updated_at,
                                                                         :activation_state])}
          else
            result = {:success => false, :message => user.errors.full_messages.to_sentence}
          end

          render :json => result
        end

        def destroy
          user = User.find(params[:id])

          render :json => {:success => user.destroy}
        end

      end #BaseController
    end #Crm
  end #Organizer
end #ErpApp