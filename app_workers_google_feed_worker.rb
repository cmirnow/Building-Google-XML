class GoogleFeedWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'cron'

  def perform(product_ids, promotion_ids)
    GoogleXmlBuilder.new(product_ids, promotion_ids).generate
  end
end
