class DocumentsController < ApplicationController
  layout nil

  before_filter(:bouncer, :only => [:show]) unless Rails.env.development?

  def show
    current_document(true)
    respond_to do |format|
      format.pdf  { redirect_to(current_document.pdf_url) }
      format.text { redirect_to(current_document.full_text_url) }
      format.html { @edits_enabled = true }
    end
  end

  def update
    json current_document(true).update_attributes(pick_params(:summary))
  end

  def destroy
    current_document(true).destroy
    json nil
  end

  # TODO: Access-control this:
  def metadata
    meta = Metadatum.all(:conditions => {:document_id => params[:ids]})
    json 'metadata' => meta
  end

  def send_pdf
    redirect_to(current_document(true).pdf_url(:direct))
  end

  def send_page_image
    return not_found unless current_page
    redirect_to(current_page.authorized_image_url)
  end

  def send_full_text
    send_data(current_document(true).text, :disposition => 'inline', :type => :txt)
  end

  def send_page_text
    return not_found unless current_page
    @response = current_page.text
    return if jsonp_request?
    render :text => @response
  end

  def set_page_text
    return not_found unless current_page
    return forbidden unless current_account.owns?(current_page)
    json current_page.update_attributes(pick_params(:text))
  end

  def search
    doc          = current_document(true)
    page_numbers = doc.pages.search_text(params[:q]).map(&:page_number)
    @response    = {'query' => params[:q], 'results' => page_numbers}
    return if jsonp_request?
    render :json => @response
  end


  private

  def current_document(exists=false)
    @current_document ||= exists ?
      Document.accessible(current_account, current_organization).find(params[:id]) :
      Document.new(:id => params[:id])
  end

  def current_page
    num = params[:page_name][/-p(\d+)/, 1]
    return bad_request unless num
    @current_page ||= current_document(true).pages.find_by_page_number(num.to_i)
  end

end