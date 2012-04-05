module FormHelper

  def automated_form_for( object, options = {} )
    object.valid?
    form_for object, :url => { :action => options[:action] } do |form|
      html_code_in_form = ""
      options[:field_names].each do |field_name|
        html_code_in_form += render :partial => "shared/form_field", :locals => { :post => object, :form => form, :field_name => field_name }
      end
      html_code_in_form += submit_tag options[:submit_label], :class => "submit"
      html_code_in_form.html_safe
    end
  end

end
