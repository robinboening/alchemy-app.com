class EssenceFilesController < ApplicationController
  
  layout 'alchemy'
  
  filter_access_to :all
  
  def edit
    @atom = Content.find(params[:id])
    @file_atom = @atom.atom
    render :layout => false
  end
  
  def update
    @content = Content.find(params[:id])
    @content.atom.update_attributes(params[:atom])
    render :update do |page|
      page << "wa_overlay.close(); reloadPreview()"
    end
  end
  
  def assign
    @content = Content.find_by_id(params[:id])
    @file = File.find_by_id(params[:file_id])
    @content.atom.file = @file
    @content.atom.save
    @content.save
    render :update do |page|
      page.replace "file_#{@content.id}", :partial => "contents/content_file_editor", :locals => {:content => @content, :options => params[:options]}
      page << "reloadPreview();wa_overlay.close()"
    end
  end
  
end