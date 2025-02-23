require "test_helper"

module Api
  class ChangesetCommentsControllerTest < ActionDispatch::IntegrationTest
    ##
    # test all routes which lead to this controller
    def test_routes
      assert_routing(
        { :path => "/api/0.6/changeset_comments", :method => :get },
        { :controller => "api/changeset_comments", :action => "index" }
      )
      assert_routing(
        { :path => "/api/0.6/changeset_comments.json", :method => :get },
        { :controller => "api/changeset_comments", :action => "index", :format => "json" }
      )
      assert_routing(
        { :path => "/api/0.6/changeset/1/comment", :method => :post },
        { :controller => "api/changeset_comments", :action => "create", :changeset_id => "1" }
      )
      assert_routing(
        { :path => "/api/0.6/changeset/1/comment.json", :method => :post },
        { :controller => "api/changeset_comments", :action => "create", :changeset_id => "1", :format => "json" }
      )
      assert_routing(
        { :path => "/api/0.6/changeset/comment/1/hide", :method => :post },
        { :controller => "api/changeset_comments", :action => "destroy", :id => "1" }
      )
      assert_routing(
        { :path => "/api/0.6/changeset/comment/1/hide.json", :method => :post },
        { :controller => "api/changeset_comments", :action => "destroy", :id => "1", :format => "json" }
      )
      assert_routing(
        { :path => "/api/0.6/changeset/comment/1/unhide", :method => :post },
        { :controller => "api/changeset_comments", :action => "restore", :id => "1" }
      )
      assert_routing(
        { :path => "/api/0.6/changeset/comment/1/unhide.json", :method => :post },
        { :controller => "api/changeset_comments", :action => "restore", :id => "1", :format => "json" }
      )
    end

    def test_index
      user1 = create(:user)
      user2 = create(:user)
      changeset1 = create(:changeset, :closed, :user => user2)
      comment11 = create(:changeset_comment, :changeset => changeset1, :author => user1, :created_at => "2023-01-01", :body => "changeset 1 question")
      comment12 = create(:changeset_comment, :changeset => changeset1, :author => user2, :created_at => "2023-02-01", :body => "changeset 1 answer")
      changeset2 = create(:changeset, :closed, :user => user1)
      comment21 = create(:changeset_comment, :changeset => changeset2, :author => user1, :created_at => "2023-03-01", :body => "changeset 2 note")
      comment22 = create(:changeset_comment, :changeset => changeset2, :author => user1, :created_at => "2023-04-01", :body => "changeset 2 extra note")
      comment23 = create(:changeset_comment, :changeset => changeset2, :author => user2, :created_at => "2023-05-01", :body => "changeset 2 review")

      get api_changeset_comments_path
      assert_response :success
      assert_comments_in_order [comment23, comment22, comment21, comment12, comment11]

      get api_changeset_comments_path(:limit => 3)
      assert_response :success
      assert_comments_in_order [comment23, comment22, comment21]

      get api_changeset_comments_path(:from => "2023-03-15T00:00:00Z")
      assert_response :success
      assert_comments_in_order [comment23, comment22]

      get api_changeset_comments_path(:from => "2023-01-15T00:00:00Z", :to => "2023-04-15T00:00:00Z")
      assert_response :success
      assert_comments_in_order [comment22, comment21, comment12]

      get api_changeset_comments_path(:user => user1.id)
      assert_response :success
      assert_comments_in_order [comment22, comment21, comment11]

      get api_changeset_comments_path(:from => "2023-03-15T00:00:00Z", :format => "json")
      assert_response :success
      js = ActiveSupport::JSON.decode(@response.body)
      assert_not_nil js
      assert_equal 2, js["comments"].count
      assert_equal comment23.id, js["comments"][0]["id"]
      assert_equal comment22.id, js["comments"][1]["id"]
    end

    def test_create_by_unauthorized
      assert_no_difference "ChangesetComment.count" do
        post api_changeset_changeset_comments_path(create(:changeset, :closed), :text => "This is a comment")
        assert_response :unauthorized
      end
    end

    def test_create_on_missing_changeset
      assert_no_difference "ChangesetComment.count" do
        post api_changeset_changeset_comments_path(999111, :text => "This is a comment"), :headers => bearer_authorization_header
        assert_response :not_found
      end
    end

    def test_create_on_open_changeset
      assert_no_difference "ChangesetComment.count" do
        post api_changeset_changeset_comments_path(create(:changeset), :text => "This is a comment"), :headers => bearer_authorization_header
        assert_response :conflict
      end
    end

    def test_create_without_text
      assert_no_difference "ChangesetComment.count" do
        post api_changeset_changeset_comments_path(create(:changeset, :closed)), :headers => bearer_authorization_header
        assert_response :bad_request
      end
    end

    def test_create_with_empty_text
      assert_no_difference "ChangesetComment.count" do
        post api_changeset_changeset_comments_path(create(:changeset, :closed), :text => ""), :headers => bearer_authorization_header
        assert_response :bad_request
      end
    end

    def test_create_when_not_agreed_to_terms
      user = create(:user, :terms_agreed => nil)
      auth_header = bearer_authorization_header user
      changeset = create(:changeset, :closed)

      assert_difference "ChangesetComment.count", 0 do
        post api_changeset_changeset_comments_path(changeset), :params => { :text => "This is a comment" }, :headers => auth_header
        assert_response :forbidden
      end
    end

    def test_create_without_required_scope
      user = create(:user)
      auth_header = bearer_authorization_header user, :scopes => %w[read_prefs]
      changeset = create(:changeset, :closed)

      assert_difference "ChangesetComment.count", 0 do
        post api_changeset_changeset_comments_path(changeset), :params => { :text => "This is a comment" }, :headers => auth_header
        assert_response :forbidden
      end
    end

    def test_create_with_write_changeset_comments_scope
      user = create(:user)
      auth_header = bearer_authorization_header user, :scopes => %w[write_changeset_comments]
      changeset = create(:changeset, :closed)

      assert_difference "ChangesetComment.count", 1 do
        post api_changeset_changeset_comments_path(changeset), :params => { :text => "This is a comment" }, :headers => auth_header
        assert_response :success
      end

      comment = ChangesetComment.last
      assert_equal changeset.id, comment.changeset_id
      assert_equal user.id, comment.author_id
      assert_equal "This is a comment", comment.body
      assert comment.visible
    end

    def test_create_with_write_api_scope
      user = create(:user)
      auth_header = bearer_authorization_header user, :scopes => %w[write_api]
      changeset = create(:changeset, :closed)

      assert_difference "ChangesetComment.count", 1 do
        post api_changeset_changeset_comments_path(changeset), :params => { :text => "This is a comment" }, :headers => auth_header
        assert_response :success
      end

      comment = ChangesetComment.last
      assert_equal changeset.id, comment.changeset_id
      assert_equal user.id, comment.author_id
      assert_equal "This is a comment", comment.body
      assert comment.visible
    end

    def test_create_on_changeset_with_no_subscribers
      changeset = create(:changeset, :closed)
      auth_header = bearer_authorization_header

      assert_difference "ChangesetComment.count", 1 do
        assert_no_difference "ActionMailer::Base.deliveries.size" do
          perform_enqueued_jobs do
            post api_changeset_changeset_comments_path(changeset, :text => "This is a comment"), :headers => auth_header
            assert_response :success
          end
        end
      end
    end

    def test_create_on_changeset_with_commenter_subscriber
      user = create(:user)
      changeset = create(:changeset, :closed, :user => user)
      changeset.subscribers << user
      auth_header = bearer_authorization_header user

      assert_difference "ChangesetComment.count", 1 do
        assert_no_difference "ActionMailer::Base.deliveries.size" do
          perform_enqueued_jobs do
            post api_changeset_changeset_comments_path(changeset, :text => "This is a comment"), :headers => auth_header
            assert_response :success
          end
        end
      end
    end

    def test_create_on_changeset_with_invisible_subscribers
      changeset = create(:changeset, :closed)
      changeset.subscribers << create(:user, :suspended)
      changeset.subscribers << create(:user, :deleted)
      auth_header = bearer_authorization_header

      assert_difference "ChangesetComment.count", 1 do
        assert_no_difference "ActionMailer::Base.deliveries.size" do
          perform_enqueued_jobs do
            post api_changeset_changeset_comments_path(changeset, :text => "This is a comment"), :headers => auth_header
            assert_response :success
          end
        end
      end
    end

    def test_create_on_changeset_with_changeset_creator_subscriber
      creator_user = create(:user)
      changeset = create(:changeset, :closed, :user => creator_user)
      changeset.subscribers << creator_user
      commenter_user = create(:user)
      auth_header = bearer_authorization_header commenter_user

      assert_difference "ChangesetComment.count", 1 do
        assert_difference "ActionMailer::Base.deliveries.size", 1 do
          perform_enqueued_jobs do
            post api_changeset_changeset_comments_path(changeset, :text => "This is a comment"), :headers => auth_header
            assert_response :success
          end
        end
      end

      email = ActionMailer::Base.deliveries.first
      assert_equal 1, email.to.length
      assert_equal "[OpenStreetMap] #{commenter_user.display_name} has commented on one of your changesets", email.subject
      assert_equal creator_user.email, email.to.first
    end

    def test_create_on_changeset_with_changeset_creator_and_other_user_subscribers
      creator_user = create(:user)
      changeset = create(:changeset, :closed, :user => creator_user)
      changeset.subscribers << creator_user
      other_user = create(:user)
      changeset.subscribers << other_user
      commenter_user = create(:user)
      auth_header = bearer_authorization_header commenter_user

      assert_difference "ChangesetComment.count", 1 do
        assert_difference "ActionMailer::Base.deliveries.size", 2 do
          perform_enqueued_jobs do
            post api_changeset_changeset_comments_path(changeset, :text => "This is a comment"), :headers => auth_header
            assert_response :success
          end
        end
      end

      email = ActionMailer::Base.deliveries.find { |e| e.to.first == creator_user.email }
      assert_not_nil email
      assert_equal 1, email.to.length
      assert_equal "[OpenStreetMap] #{commenter_user.display_name} has commented on one of your changesets", email.subject

      email = ActionMailer::Base.deliveries.find { |e| e.to.first == other_user.email }
      assert_not_nil email
      assert_equal 1, email.to.length
      assert_equal "[OpenStreetMap] #{commenter_user.display_name} has commented on a changeset you are interested in", email.subject
    end

    ##
    # create comment rate limit for new users
    def test_create_by_new_user_with_rate_limit
      changeset = create(:changeset, :closed)
      user = create(:user)

      auth_header = bearer_authorization_header user

      assert_difference "ChangesetComment.count", Settings.initial_changeset_comments_per_hour do
        1.upto(Settings.initial_changeset_comments_per_hour) do |count|
          post api_changeset_changeset_comments_path(changeset, :text => "Comment #{count}"), :headers => auth_header
          assert_response :success
        end
      end

      assert_no_difference "ChangesetComment.count" do
        post api_changeset_changeset_comments_path(changeset, :text => "One comment too many"), :headers => auth_header
        assert_response :too_many_requests
      end
    end

    ##
    # create comment rate limit for experienced users
    def test_create_by_experienced_user_with_rate_limit
      changeset = create(:changeset, :closed)
      user = create(:user)
      create_list(:changeset_comment, Settings.comments_to_max_changeset_comments, :author_id => user.id, :created_at => Time.now.utc - 1.day)

      auth_header = bearer_authorization_header user

      assert_difference "ChangesetComment.count", Settings.max_changeset_comments_per_hour do
        1.upto(Settings.max_changeset_comments_per_hour) do |count|
          post api_changeset_changeset_comments_path(changeset, :text => "Comment #{count}"), :headers => auth_header
          assert_response :success
        end
      end

      assert_no_difference "ChangesetComment.count" do
        post api_changeset_changeset_comments_path(changeset, :text => "One comment too many"), :headers => auth_header
        assert_response :too_many_requests
      end
    end

    ##
    # create comment rate limit for reported users
    def test_create_by_reported_user_with_rate_limit
      changeset = create(:changeset, :closed)
      user = create(:user)
      create(:issue_with_reports, :reportable => user, :reported_user => user)

      auth_header = bearer_authorization_header user

      assert_difference "ChangesetComment.count", Settings.initial_changeset_comments_per_hour / 2 do
        1.upto(Settings.initial_changeset_comments_per_hour / 2) do |count|
          post api_changeset_changeset_comments_path(changeset, :text => "Comment #{count}"), :headers => auth_header
          assert_response :success
        end
      end

      assert_no_difference "ChangesetComment.count" do
        post api_changeset_changeset_comments_path(changeset, :text => "One comment too many"), :headers => auth_header
        assert_response :too_many_requests
      end
    end

    ##
    # create comment rate limit for moderator users
    def test_create_by_moderator_user_with_rate_limit
      changeset = create(:changeset, :closed)
      user = create(:moderator_user)

      auth_header = bearer_authorization_header user

      assert_difference "ChangesetComment.count", Settings.moderator_changeset_comments_per_hour do
        1.upto(Settings.moderator_changeset_comments_per_hour) do |count|
          post api_changeset_changeset_comments_path(changeset, :text => "Comment #{count}"), :headers => auth_header
          assert_response :success
        end
      end

      assert_no_difference "ChangesetComment.count" do
        post api_changeset_changeset_comments_path(changeset, :text => "One comment too many"), :headers => auth_header
        assert_response :too_many_requests
      end
    end

    def test_hide_by_unauthorized
      comment = create(:changeset_comment)

      post changeset_comment_hide_path(comment)

      assert_response :unauthorized
      assert comment.reload.visible
    end

    def test_hide_by_normal_user
      comment = create(:changeset_comment)
      auth_header = bearer_authorization_header

      post changeset_comment_hide_path(comment), :headers => auth_header

      assert_response :forbidden
      assert comment.reload.visible
    end

    def test_hide_missing_comment
      auth_header = bearer_authorization_header create(:moderator_user)

      post changeset_comment_hide_path(999111), :headers => auth_header

      assert_response :not_found
    end

    def test_hide_without_required_scope
      comment = create(:changeset_comment)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[read_prefs]

      post changeset_comment_hide_path(comment), :headers => auth_header

      assert_response :forbidden
      assert comment.reload.visible
    end

    def test_hide_with_write_changeset_comments_scope
      comment = create(:changeset_comment)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[write_changeset_comments]

      post changeset_comment_hide_path(comment), :headers => auth_header

      assert_response :success
      assert_equal "application/xml", response.media_type
      assert_dom "osm", 1 do
        assert_dom "> changeset", 1 do
          assert_dom "> @id", comment.changeset_id.to_s
          assert_dom "> @comments_count", "0"
        end
      end

      assert_not comment.reload.visible
    end

    def test_hide_with_write_changeset_comments_scope_json
      comment = create(:changeset_comment)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[write_changeset_comments]

      post changeset_comment_hide_path(comment, :format => "json"), :headers => auth_header

      assert_response :success
      assert_equal "application/json", response.media_type
      js = ActiveSupport::JSON.decode(@response.body)
      assert_not_nil js["changeset"]
      assert_equal comment.changeset_id, js["changeset"]["id"]
      assert_equal 0, js["changeset"]["comments_count"]

      assert_not comment.reload.visible
    end

    def test_hide_with_write_api_scope
      comment = create(:changeset_comment)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[write_api]

      post changeset_comment_hide_path(comment), :headers => auth_header

      assert_response :success
      assert_equal "application/xml", response.media_type
      assert_dom "osm", 1 do
        assert_dom "> changeset", 1 do
          assert_dom "> @id", comment.changeset_id.to_s
          assert_dom "> @comments_count", "0"
        end
      end

      assert_not comment.reload.visible
    end

    def test_hide_with_write_api_scope_json
      comment = create(:changeset_comment)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[write_api]

      post changeset_comment_hide_path(comment, :format => "json"), :headers => auth_header

      assert_response :success
      assert_equal "application/json", response.media_type
      js = ActiveSupport::JSON.decode(@response.body)
      assert_not_nil js["changeset"]
      assert_equal comment.changeset_id, js["changeset"]["id"]
      assert_equal 0, js["changeset"]["comments_count"]

      assert_not comment.reload.visible
    end

    def test_unhide_by_unauthorized
      comment = create(:changeset_comment, :visible => false)

      post changeset_comment_unhide_path(comment)

      assert_response :unauthorized
      assert_not comment.reload.visible
    end

    def test_unhide_by_normal_user
      comment = create(:changeset_comment, :visible => false)
      auth_header = bearer_authorization_header

      post changeset_comment_unhide_path(comment), :headers => auth_header

      assert_response :forbidden
      assert_not comment.reload.visible
    end

    def test_unhide_missing_comment
      auth_header = bearer_authorization_header create(:moderator_user)

      post changeset_comment_unhide_path(999111), :headers => auth_header

      assert_response :not_found
    end

    def test_unhide_without_required_scope
      comment = create(:changeset_comment, :visible => false)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[read_prefs]

      post changeset_comment_unhide_path(comment), :headers => auth_header

      assert_response :forbidden
      assert_not comment.reload.visible
    end

    def test_unhide_with_write_changeset_comments_scope
      comment = create(:changeset_comment, :visible => false)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[write_changeset_comments]

      post changeset_comment_unhide_path(comment), :headers => auth_header

      assert_response :success
      assert_equal "application/xml", response.media_type
      assert_dom "osm", 1 do
        assert_dom "> changeset", 1 do
          assert_dom "> @id", comment.changeset_id.to_s
          assert_dom "> @comments_count", "1"
        end
      end

      assert comment.reload.visible
    end

    def test_unhide_with_write_changeset_comments_scope_json
      comment = create(:changeset_comment, :visible => false)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[write_changeset_comments]

      post changeset_comment_unhide_path(comment, :format => "json"), :headers => auth_header

      assert_response :success
      assert_equal "application/json", response.media_type
      js = ActiveSupport::JSON.decode(@response.body)
      assert_not_nil js["changeset"]
      assert_equal comment.changeset_id, js["changeset"]["id"]
      assert_equal 1, js["changeset"]["comments_count"]

      assert comment.reload.visible
    end

    def test_unhide_with_write_api_scope
      comment = create(:changeset_comment, :visible => false)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[write_api]

      post changeset_comment_unhide_path(comment), :headers => auth_header

      assert_response :success
      assert_equal "application/xml", response.media_type
      assert_dom "osm", 1 do
        assert_dom "> changeset", 1 do
          assert_dom "> @id", comment.changeset_id.to_s
          assert_dom "> @comments_count", "1"
        end
      end

      assert comment.reload.visible
    end

    def test_unhide_with_write_api_scope_json
      comment = create(:changeset_comment, :visible => false)
      auth_header = bearer_authorization_header create(:moderator_user), :scopes => %w[write_api]

      post changeset_comment_unhide_path(comment, :format => "json"), :headers => auth_header

      assert_response :success
      js = ActiveSupport::JSON.decode(@response.body)
      assert_equal "application/json", response.media_type
      assert_not_nil js["changeset"]
      assert_equal comment.changeset_id, js["changeset"]["id"]
      assert_equal 1, js["changeset"]["comments_count"]

      assert comment.reload.visible
    end

    private

    ##
    # check that certain comments exist in the output in the specified order
    def assert_comments_in_order(comments)
      assert_dom "osm > comment", comments.size do |dom_comments|
        comments.zip(dom_comments).each do |comment, dom_comment|
          assert_dom dom_comment, "> @id", comment.id.to_s
          assert_dom dom_comment, "> @uid", comment.author.id.to_s
          assert_dom dom_comment, "> @user", comment.author.display_name
          assert_dom dom_comment, "> text", comment.body
        end
      end
    end
  end
end
