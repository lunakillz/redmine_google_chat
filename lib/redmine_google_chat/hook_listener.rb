require 'net/http'
require 'net/https'
require 'uri'
  
module RedmineGoogleChat
	class HookListener < Redmine::Hook::Listener
		def controller_issues_new_after_save(context = {})
			issue = context[:issue]
			controller = context[:controller]
			post(issue_to_json(issue, controller))
		end
	
		def controller_issues_edit_after_save(context = {})
			issue = context[:issue]
			journal = context[:journal]
			controller = context[:controller]
			post(journal_to_json(issue, journal, controller))
		end
	

		def controller_issues_bulk_edit_after_save(context = {})
			controller = context[:controller]
			issue = context[:issue]
			
			#post(webhooks, journal_to_json(issue, journal, controller))
		end
		
		
		def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context={})
		end
	
		def controller_wiki_edit_after_save(context = {})
		end
	
		
	
		private
		def issue_to_json(issue, controller)
			text = "#{issue.author.to_s} *created* #{escape issue}"
			card = {}

			card[:header] = {
				:title => "`#{escape issue.project}`",
				:subtitle => "#{mentions issue.description}"
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
					:contentMultiline => "false",
				}
			} if issue.assigned_to

			linkSection = [
				:buttons => [
					:textButton => {
						:text => "OPEN ISSUE",
						:onClick => {
							:openLink => {
								:url => controller.issue_url(issue)
							}
						}
					}
				]
			]
	
			card[:sections] = [
				{
					:widgets => widgets
				},
				{
					:widgets => linkSection
				}
			]
	
			{
				:text => text,
				:cards => card
			}.to_json
		end

		def journal_to_json(issue, journal, controller)
			text = "#{journal.user.to_s} *updated* #{escape issue}"
			card = {
				:sections => [
				]
			}

			fields = journal.details.map { |d| detail_to_field d }

			card[:sections] << {
					:widgets => fields
			} if fields.size > 0

			card[:sections] << {
					:widgets => [
							{
								:textParagraph => {
										:text => escape(journal.notes)
								}
							}
					]
			} if journal.notes

			linkSection = [
				:buttons => [
					:textButton => {
						:text => "OPEN ISSUE",
						:onClick => {
							:openLink => {
								:url => controller.issue_url(issue)
							}
						}
					}
				]
			]
	
			card[:sections] = [
				{
					:widgets => widgets
				},
				{
					:widgets => linkSection
				}
			]
			{
				:text => text,
				:cards => card
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
	
	
		def mentions text
			return nil if text.nil?
			names = extract_usernames text
			names.present? ? "\nTo: " + names.join(', ') : nil
		end
	
		def extract_usernames text = ''
			if text.nil?
				text = ''
			end
	
			text.scan(/@[a-z0-9][a-z0-9_\-]*/).uniq
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

		def post(body)
			url = Setting.plugin_redmine_google_chat['webhook_url'] if not url
			begin
				uri = URI.parse(url)
				https = Net::HTTP.new(uri.host,uri.port)
				Rails.logger.info("uri.qeury #{uri.query}")
				https.use_ssl = true
				req = Net::HTTP::Post.new(uri,initheader = {'Content-Type' =>'application/json'})
				req.body = body
				res = https.request(req)
			rescue Exception => e
				Rails.logger.warn("cannot connect to #{url}")
				Rails.logger.warn(e)
			end
		end
	end
	
end
