# -*- coding: utf-8 -*-
require 'spec_helper'

feature 'User page', js: false do
  background do
    User.destroy_all
    @user = create( :user_with_account )
    @login_string = @user.alias
    @password = @user.account.password
  end

  subject { page }
  
  describe 'when not signed in' do
    background do
      visit user_path( @user )
    end
    
    #it { should have_content "Access denied" }
  end

  describe 'when signed in' do
    background do

      visit new_session_path
      fill_in 'login_name', with: @login_string
      fill_in 'password', with: @password
      click_button I18n.t( :login )

      visit user_path( @user )
    end
  
    it { should have_selector('h1', text: I18n.t( :about_myself ) ) }
    it { should have_selector('h1', text: I18n.t( :study_information ) ) }
    it { should have_selector('h1', text: I18n.t( :career_information ) ) }
    it { should have_selector('h1', text: I18n.t( :organizations ) ) }

    #it { should have_selector('title', text: 'Wingolfsplattform') } #can't get it to work on capybara 2.0


    scenario 'the section \'organizations\'', js: true do
      within('.box.section.organizations') do
        click_on I18n.t(:edit)
        page.should have_selector('a.add_button', visible: true)

        click_on I18n.t(:add)
        page.should have_selector('.profile_field')
        within first '.profile_field' do
          page.should have_selector('input[type=text]', count: 6)
        end

        find('.remove_button').click
        page.should_not have_selector('li')
      end
    end

  end
end