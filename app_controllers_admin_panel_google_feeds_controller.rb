class AdminPanel::GoogleFeedsController < AdminPanelController
  def new
    @promotions = Promotion.actual.joins(:products).distinct
  end

  def create
    load_products
    GoogleFeedWorker.perform_async(@products.ids, params[:promotion_ids])
    redirect_to admin_panel_new_google_feed_path, notice: "Feed generation #{params[:promotion_ids]} can take from 1 to 30 minutes."
  end

  private

  def load_products
    promotions = Promotion.actual.where(id: params[:promotion_ids])
    @products = if promotions.present?
      Product.joins(:promotions).merge(promotions).uniq
    else
      Product.all
    end
  end
end
