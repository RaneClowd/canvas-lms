#
# Copyright (C) 2015 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe LiveEventsObserver do
  describe "general" do
    it "doesn't post events for no change" do
      user_model(name: "Joey Joe Joe")

      @user.name = "Joey Joe Joe"
      expect(Canvas::LiveEvents).to receive(:user_updated).never
      @user.save!
    end
    it "doesn't post events for NOP fields" do
      account_model
      course_model(name: "CS101", account: @account)
      sis = @account.sis_batches.create

      @course.name = "CS101"
      @course.sis_batch_id = sis.id
      expect(Canvas::LiveEvents).to receive(:course_updated).never
      @course.save!
    end
    it "does post event for actual change" do
      user_model(name: "Joey Joe Joe")

      @user.name = "Joey Joe Joe Jr. Shabadu"
      expect(Canvas::LiveEvents).to receive(:user_updated).once
      @user.save!
    end
  end
  describe "syllabus" do
    it "doesn't post for no changes" do
      course_model
      @course.syllabus_body = "old syllabus"
      @course.save!

      expect(Canvas::LiveEvents).to receive(:course_syllabus_updated).never
      @course.save!
    end

    it "posts update events" do
      course_model
      @course.syllabus_body = "old syllabus"
      @course.save!

      @course.syllabus_body = "new syllabus"
      expect(Canvas::LiveEvents).to receive(:course_syllabus_updated).with(@course, "old syllabus")
      @course.save
    end
  end

  describe "wiki" do
    it "posts create events" do
      expect(Canvas::LiveEvents).to receive(:wiki_page_created).once
      wiki_page_model
    end

    it "posts update events for title" do
      wiki_page_model(title: 'old title')
      expect(Canvas::LiveEvents).to receive(:wiki_page_updated).with(@page, 'old title', nil)
      @page.title = 'new title'
      @page.save
    end

    it "posts update events for body" do
      wiki_page_model(body: 'old body')
      expect(Canvas::LiveEvents).to receive(:wiki_page_updated).with(@page, nil, 'old body')
      @page.body = 'new body'
      @page.save
    end

    it "does not post trivial update events" do
      wiki_page_model
      expect(Canvas::LiveEvents).to receive(:wiki_page_updated).never
      @page.touch
    end

    it "posts soft delete events" do
      wiki_page_model
      expect(Canvas::LiveEvents).to receive(:wiki_page_deleted).once
      @page.destroy
    end

    it "posts delete events" do
      wiki_page_model
      expect(Canvas::LiveEvents).to receive(:wiki_page_deleted).once
      @page.destroy_permanently!
    end
  end

  describe "course" do
    it "posts create events" do
      expect(Canvas::LiveEvents).to receive(:course_created).once
      course_model
    end

    it "posts update events" do
      expect(Canvas::LiveEvents).to receive(:course_updated).twice
      course_model # creation fires updated as well
      @course.name = "Name Changed"
      @course.save
    end
  end

  describe "discussion topic" do
    it "posts create events" do
      course_model
      expect(Canvas::LiveEvents).to receive(:discussion_topic_created).once
      discussion_topic_model(context: @course)
    end
  end

  describe "discussion entry" do
    it "posts create events" do
      course_model
      expect(Canvas::LiveEvents).to receive(:discussion_entry_created).once
      discussion_topic_model(context: @course)
      @topic.discussion_entries.create!(:message => 'entry')
    end
  end

  describe "group" do
    it "posts create events for group_categories" do
      course = course_model
      expect(Canvas::LiveEvents).to receive(:group_category_created).once
      course.group_categories.create!(name: "project A", create_group_count: 2)
    end

    it "posts create events for groups" do
      course = course_model
      expect(Canvas::LiveEvents).to receive(:group_created).twice
      course.groups.create!(name: "Group 1")
      course.groups.create!(name: "Group 2")
    end

    it "posts update events for groups" do
      course = course_model
      group = course.groups.create!(name: "Group 1")
      expect(Canvas::LiveEvents).to receive(:group_updated).once
      group.name = "New Group Name"
      group.save
    end

    it "posts create events for group_memberships" do
      course = course_model
      student1 = course.enroll_student(user_model).user
      student2 = course.enroll_student(user_model).user
      group1 = course.groups.create!(name: "Group 1")
      group2 = course.groups.create!(name: "Group 2")
      expect(Canvas::LiveEvents).to receive(:group_membership_created).twice
      group1.add_user(student1)
      group2.add_user(student2)
    end

    it "posts update events for group_memberships" do
      course = course_model
      student = course.enroll_student(user_model).user
      group = course.groups.create!(name: "Group 1")
      membership = group.add_user(student)
      expect(Canvas::LiveEvents).to receive(:group_membership_updated).once
      membership.moderator = true
      membership.save
    end
  end

  describe "assignment" do
    it "posts create events" do
      expect(Canvas::LiveEvents).to receive(:assignment_created).once
      assignment_model
    end

    it "posts update events" do
      expect(Canvas::LiveEvents).to receive(:assignment_updated).once
      assignment_model(:title => "original")
      @assignment.title = "new title"
      @assignment.save
    end
  end

  describe "submission" do
    it "posts create events" do
      expect(Canvas::LiveEvents).to receive(:submission_created).once
      submission_model
    end

    it "posts update events" do
      expect(Canvas::LiveEvents).to receive(:submission_updated).once
      s = submission_model
      s.excused = true
      s.save!
    end
  end

  describe "user" do
    it "posts create events" do
      expect(Canvas::LiveEvents).to receive(:user_created).once
      user_model
    end

    it "posts update events" do
      expect(Canvas::LiveEvents).to receive(:user_updated).once
      user_model
      @user.name = "Name Changed"
      @user.save
    end
  end

  describe "enrollment" do
    it "posts create events" do
      expect(Canvas::LiveEvents).to receive(:enrollment_created).once
      course_with_student
    end

    it "posts update events" do
      expect(Canvas::LiveEvents).to receive(:enrollment_updated).once
      course_with_student
      @enrollment.workflow_state = 'rejected'
      @enrollment.save
    end
  end

  describe "enrollment_state" do
    it "posts create events" do
      expect(Canvas::LiveEvents).to receive(:enrollment_state_created).once
      course_with_student
    end

    it "posts update events" do
      expect(Canvas::LiveEvents).to receive(:enrollment_state_updated).once
      course_with_student
      @enrollment.limit_privileges_to_course_section = true
      @enrollment.save
    end
  end

  describe "user_account_association" do
    it "posts create events" do
      expect(Canvas::LiveEvents).to receive(:user_account_association_created).once
      user_with_pseudonym(account: Account.default, username: 'bobbo', active_all: true)
    end
  end

  describe "account_notification" do
    it "posts create events" do
      expect(Canvas::LiveEvents).to receive(:account_notification_created).once
      account_notification
    end
  end

  describe "quiz_export_complete" do
    it "posts update events for quizzes2" do
      expect(Canvas::LiveEvents).to receive(:quiz_export_complete).once
      Account.default.enable_feature!(:quizzes2_exporter)
      course = Account.default.courses.create!
      Account.default.context_external_tools.create!(
        name: 'Quizzes.Next',
        consumer_key: 'test_key',
        shared_secret: 'test_secret',
        tool_id: 'Quizzes 2',
        url: 'http://example.com/launch'
      )
      quiz = course.quizzes.create!(:title => 'quiz1')
      ce = course.content_exports.create!(
        :export_type => ContentExport::QUIZZES2,
        :selected_content => quiz.id,
        :user => user_model
      )
      ce.export_without_send_later
    end

    it "does not post for other ContentExport types" do
      expect(Canvas::LiveEvents).to receive(:quiz_export_complete).never
      course = Account.default.courses.create!
      ce = course.content_exports.create!
      ce.export_without_send_later
    end
  end
end
