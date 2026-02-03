class MessagesController < ApplicationController
  def create
    @room = Room.find(params[:room_id])
    @message = @room.messages.create(message_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to room_path(@room) }
    end
  end

  private

  def message_params
    params.expect(message: [ :content, :sender_name ])
  end
end
