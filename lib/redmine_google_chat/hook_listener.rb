require 'httpclient'
  
module RedmineGoogleChat
	class HookListener < Redmine::Hook::Listener
		def issues_new_after_save(context={})
			issue = context[:issue]
			controller = context[:controller]
			return if issue.is_private?
			post(issue_to_json(issue, controller))
		end
	
		def issues_edit_after_save(context={})
			issue = context[:issue]
			controller = context[:controller]
			return if issue.is_private?
			post(issue_to_json(issue, controller))
		end
	
		def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context={})
			# issue = context[:issue]
			# journal = issue.current_journal
			# changeset = context[:changeset]
	
			# thread = thread_for_project issue.project
			# url = url_for_project issue.project
	
			# return unless thread and url and issue.save
			# return if issue.is_private?
	
			# msg = {
			# 	:project_name => issue.project,
			# 	:author => journal.user.to_s,
			# 	:action => "updated",
			# 	:link => object_url(issue),
			# 	:issue => issue
			# }
	
			# repository = changeset.repository
	
			# if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
			# 	host, port, prefix = $2, $4, $5
			# 	revision_url = Rails.application.routes.url_for(
			# 		:controller => 'repositories',
			# 		:action => 'revision',
			# 		:id => repository.project,
			# 		:repository_id => repository.identifier_param,
			# 		:rev => changeset.revision,
			# 		:host => host,
			# 		:protocol => Setting.protocol,
			# 		:port => port,
			# 		:script_name => prefix
			# 	)
			# else
			# 	revision_url = Rails.application.routes.url_for(
			# 		:controller => 'repositories',
			# 		:action => 'revision',
			# 		:id => repository.project,
			# 		:repository_id => repository.identifier_param,
			# 		:rev => changeset.revision,
			# 		:host => Setting.host_name,
			# 		:protocol => Setting.protocol
			# 	)
			# end
	
			# card = {
			# 	:header => {
			# 		:title => ll(Setting.default_language, :text_status_changed_by_changeset, "<a href=\"#{revision_url}\">#{escape changeset.comments}</a>")
			# 	},
			# 	:sections => []
			# }
	
			# card[:sections] << {
			# 	:widgets => journal.details.map { |d| detail_to_field d }
			# }
	
			# speak msg, thread, card, url
		end
	
		def controller_wiki_edit_after_save(context = { })
			# return unless Setting.plugin_redmine_hangouts_chat['post_wiki_updates'] == '1'
	
			# project = context[:project]
			# page = context[:page]
	
			# user = page.content.author
	
			# thread = thread_for_project project
			# url = url_for_project project
	
			# card = nil
			# if not page.content.comments.empty?
			# 	card = {
			# 		:header => {
			# 			:title => "#{escape page.content.comments}"
			# 		}
			# 	}
			# end
	
			# comment = {
			# 	:project_name => project,
			# 	:author => user,
			# 	:action => "updated",
			# 	:link => object_url(page),
			# 	:project_link => object_url(project)
			# }
	
			# speak comment, thread, card, url
		end
	
		
	
	private
		def issue_to_json(issue, controller)
			msg = {
				:project_name => issue.project,
				:author => issue.author.to_s,
				:action => "created",
				:issue => issue,
				:link => controller.issue_url(issue),
				:mentions => "#{mentions issue.description}"
			}
			card = {}
			card[:header] = {
				:title => "#{msg[:author]} #{msg[:action]} #{escape msg[:issue]} #{msg[:mentions]}",
				:subtitle => "#{escape msg[:project_name]}"
			}
			widgets = [{
				:keyValue => {
					:topLabel => I18n.t("field_status"),
					:content => escape(issue.status.to_s),
					:contentMultiline => "false"
					}
				}, {
				:keyValue => {
					:topLabel => I18n.t("field_priority"),
					:content => escape(issue.priority.to_s),
					:contentMultiline => "false"
				}
			}]
	
			widgets << {
				:keyValue => {
					:topLabel => I18n.t("field_assigned_to"),
					:content => escape(issue.assigned_to.to_s),
					:contentMultiline => "false"
				}
			} if issue.assigned_to
	
			card[:sections] = [
				{
					:widgets => widgets
				}
			]
	
			{
				:card => card
			}.to_json
		end

		def escape(msg)
			msg.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
		end
	
		def object_url(obj)
			if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
				host, port, prefix = $2, $4, $5
				Rails.application.routes.url_for(obj.event_url({
					:host => host,
					:protocol => Setting.protocol,
					:port => port,
					:script_name => prefix
				}))
			else
				Rails.application.routes.url_for(obj.event_url({
					:host => Setting.host_name,
					:protocol => Setting.protocol
				}))
			end
		end
	
		def detail_to_field(detail)
			if detail.property == "cf"
				key = CustomField.find(detail.prop_key).name rescue nil
				title = key
			elsif detail.property == "attachment"
				key = "attachment"
				title = I18n.t :label_attachment
			else
				key = detail.prop_key.to_s.sub("_id", "")
				if key == "parent"
					title = I18n.t "field_#{key}_issue"
				else
					title = I18n.t "field_#{key}"
				end
			end
	
			short = true
			value = escape detail.value.to_s
	
			case key
			when "title", "subject", "description"
				short = false
			when "tracker"
				tracker = Tracker.find(detail.value) rescue nil
				value = escape tracker.to_s
			when "project"
				project = Project.find(detail.value) rescue nil
				value = escape project.to_s
			when "status"
				status = IssueStatus.find(detail.value) rescue nil
				value = escape status.to_s
			when "priority"
				priority = IssuePriority.find(detail.value) rescue nil
				value = escape priority.to_s
			when "category"
				category = IssueCategory.find(detail.value) rescue nil
				value = escape category.to_s
			when "assigned_to"
				user = User.find(detail.value) rescue nil
				value = escape user.to_s
			when "fixed_version"
				version = Version.find(detail.value) rescue nil
				value = escape version.to_s
			when "attachment"
				attachment = Attachment.find(detail.prop_key) rescue nil
				value = "<#{object_url attachment}|#{escape attachment.filename}>" if attachment
			when "parent"
				issue = Issue.find(detail.value) rescue nil
				value = "<#{object_url issue}|#{escape issue}>" if issue
			end
	
			value = "-" if value.empty?
	
			result = { 
				:keyValue => { 
					:topLabel => title,
					:content => value 
				} 
			} 
			result[:keyValue][:contentMultiline] = "true" if not short
			result
		end
	
		def mentions text
			return nil if text.nil?
			names = extract_usernames text
			names.present? ? "\nTo: " + names.join(', ') : nil
		end
	
		def extract_usernames text = ''
			if text.nil?
				text = ''
			end
	
			# slack usernames may only contain lowercase letters, numbers,
			# dashes and underscores and must start with a letter or number.
			text.scan(/@[a-z0-9][a-z0-9_\-]*/).uniq
		end

		def post(body)

			url = Setting.plugin_redmine_google_chat['webhook_url'] if not url
	
			begin
				client = HTTPClient.new
				client.ssl_config.cert_store.set_default_paths
				client.ssl_config.ssl_version = :auto
				client.post_async url, {:body => body, :header => {'Content-Type' => 'application/json'}}
			rescue Exception => e
				Rails.logger.warn("cannot connect to #{url}")
				Rails.logger.warn(e)
			end
		end
	end
	
end
