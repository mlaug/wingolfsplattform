module ToolButtonsHelper
  
  def remove_button( object )
    title = t(:remove)
    title += ": " + object.title if object.respond_to?(:title) && object.title.present?
    link_to( tool_icon( "icon-trash icon-white" ),
             object,
             method: 'delete',
             :class => 'remove_button tool show_only_in_edit_mode btn btn-danger btn-small',
             :title => title,
             :remote => true
           )
  end

  def add_button( url, options = {} )

    # label for the button = icon + "add"
    label = tool_icon( "icon-plus icon-black" ) + " " + t( :add )

    # default options
    options = { 
      :class => 'add_button tool show_only_in_edit_mode btn',
      :remote => true
    }.merge( options )
    
    # create the link_to tag
    link_to( label, url.to_s, options )

  end

  def edit_button( options = {} )
    tool_button :edit, "icon-edit icon-black", t(:edit), options
  end

  def save_button( options = {} )
    tool_button( :save, "icon-ok icon-white", "", 
                 :class => "save_button button btn btn-primary", :title => t(:save) )
  end    

  def cancel_button( options = {} )
    tool_button( :cancel, "icon-remove icon-black", "", 
                 :title => t(:cancel) )
  end
  
  private
  
  def tool_button( type, icon, text, options = {} )
    css_class = "button #{type}_button btn #{options[ :class ]}"; options.delete( :class )
    options = { :class => css_class }.merge( options )
    href = options[ :href ]
    href = "#" unless href
    options.delete( :href )
    link_to( tool_icon( icon ) + " " + text,
             href,
             options )
  end  

  def tool_icon( type )
    content_tag( :i, "", :class => "#{type}" )
  end

end
