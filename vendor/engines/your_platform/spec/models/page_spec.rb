require 'spec_helper'

describe Page do

  def create_page_structure
    Page.destroy_all # in case there are already pages defined elsewhere
    @root = create( :page, title: "Root" )
    @intranet_root = create( :page, title: "Intranet Root" )
    @some_page = create( :page, title: "Some Page" )

    @intranet_root.add_flag( :intranet_root )

    @root.child_pages << @intranet_root
    @root.add_flag( :root )
    @intranet_root.child_pages << @some_page
  end

  subject { create( :page ) }


  # General Properties
  # ----------------------------------------------------------------------------------------------------

  it { should respond_to( :content, :content=, :title, :title= ) }

  it "should be structureable" do
    subject.should respond_to( :parents, :children, :ancestors, :descendants )
  end

  it "should be navable" do
    subject.should respond_to( :nav_node )
  end

  it "should have attachments" do
    subject.should respond_to( :attachments )
    subject.attachments.should == []
  end
  

  # Quick Assignment of Children
  # ----------------------------------------------------------------------------------------------------
  
  describe "#<<", :focus do
    before { @page = create(:page) }
    subject { @page << @object_to_add }
    
    describe "( page )" do
      before { @object_to_add = create(:page) }
      before { subject }
      it "should add the other page as a child" do
        @page.children.should include @object_to_add
      end
    end
    
    describe "( blog_post )" do
      before { @object_to_add = create(:blog_post) }
      before { subject }
      it "should add the blog post as a child" do
        @page.children.should include @object_to_add
      end
    end
    
    describe "( group )" do
      before { @object_to_add = create(:group) }
      before { subject }
      it "should add the group as a child" do
        @page.children.should include @object_to_add
      end
    end
    
    describe "adding an object that is already a descendant" do
      #
      #  @group
      #     |----- @page
      #     |        |
      #     |        | <----------------- this relation is added
      #     |        |
      #     |----- @object_to_add
      #
      before do
        @object_to_add = create(:page)
        @group = create(:group)
        @group.child_pages << @object_to_add
        @page = create(:page)
        @page.parent_groups << @group
      end
      before { subject }
      it "should add the object as a direct child" do
        @page.children.should include @object_to_add
      end
      it "should not unassign the object of the group" do
        @group.children.should include @object_to_add
      end
    end
  end


  # Redirection
  # ----------------------------------------------------------------------------------------------------

  describe "#redirect_to" do
    before { @page = create(:page) }
    subject { @page.redirect_to }
    describe "for urls with given protocol" do
      before { @page.redirect_to = "http://example.com" }
      it "should return the url" do
        subject.should == "http://example.com"
      end
    end
    describe "for controller#action strings" do
      before { @page.redirect_to = "users#index" }
      it "should return a Hash with controller and index" do
        subject.should == { controller: "users", action: "index" }
      end
    end
  end

  describe "#redirect_to=" do
    before { @page = create(:page) }
    subject { @page.redirect_to = @redirect_to }
    describe "for setting it to a url with protocol" do
      before { @redirect_to = "http://example.com" }
      it "should store the url" do
        subject
        @page.read_attribute(:redirect_to).should == @redirect_to
      end
      it "should retrieve the url unchanged" do
        subject
        @page.redirect_to.should == @redirect_to
      end
    end
    describe "for setting it to a controller#action string" do
      before { @redirect_to = "users#index" }
      it "should store the controller#action string" do
        subject
        @page.read_attribute(:redirect_to).should == @redirect_to
      end
      it "should retrieve a Hash with controller and action" do
        subject
        @page.redirect_to.should == { controller: "users", action: "index" }
      end
    end
    describe "for setting it to a Hash with controller and action" do
      before { @redirect_to = { controller: "users", action: "index" } }
      it "should retrieve it as a Hash with controller and action" do
        subject
        @page.redirect_to.should == @redirect_to
      end
    end
  end


  # Association Related Methods
  # ----------------------------------------------------------------------------------------------------

  describe "#attachments_by_type" do
    it "should be the same as #attachments.find_by_type" do
      type = "image"
      subject.attachments_by_type( type ).should == subject.attachments.find_by_type( type )
    end
  end


  # Finder Methods
  # ----------------------------------------------------------------------------------------------------

  describe "#find_root" do
    before { create_page_structure }
    subject { Page.find_root }

    it "should return the root page" do
      subject.should == @root
    end
  end

  describe "#find_intranet_root" do
    before { create_page_structure }
    subject { Page.find_intranet_root }

    it "should return the intranet root page" do
      subject.should == @intranet_root
    end
  end

end
