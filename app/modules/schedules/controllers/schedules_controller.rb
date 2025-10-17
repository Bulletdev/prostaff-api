# frozen_string_literal: true

module Schedules
  module Controllers
    class SchedulesController < Api::V1::BaseController
      before_action :set_schedule, only: [:show, :update, :destroy]
      
      def index
      schedules = organization_scoped(Schedule).includes(:match)
      
      schedules = schedules.where(event_type: params[:event_type]) if params[:event_type].present?
      schedules = schedules.where(status: params[:status]) if params[:status].present?
      
      if params[:start_date].present? && params[:end_date].present?
      schedules = schedules.where(start_time: params[:start_date]..params[:end_date])
      elsif params[:upcoming] == 'true'
      schedules = schedules.where('start_time >= ?', Time.current)
      elsif params[:past] == 'true'
      schedules = schedules.where('end_time < ?', Time.current)
      end
      
      if params[:today] == 'true'
      schedules = schedules.where(start_time: Time.current.beginning_of_day..Time.current.end_of_day)
      end
      
      if params[:this_week] == 'true'
      schedules = schedules.where(start_time: Time.current.beginning_of_week..Time.current.end_of_week)
      end
      
      sort_order = params[:sort_order] || 'asc'
      schedules = schedules.order("start_time #{sort_order}")
      
      result = paginate(schedules)
      
      render_success({
      schedules: ScheduleSerializer.render_as_hash(result[:data]),
      pagination: result[:pagination]
      })
      end
      
      def show
      render_success({
      schedule: ScheduleSerializer.render_as_hash(@schedule)
      })
      end
      
      def create
      schedule = organization_scoped(Schedule).new(schedule_params)
      schedule.organization = current_organization
      
      if schedule.save
      log_user_action(
      action: 'create',
      entity_type: 'Schedule',
      entity_id: schedule.id,
      new_values: schedule.attributes
      )
      
      render_created({
      schedule: ScheduleSerializer.render_as_hash(schedule)
      }, message: 'Event scheduled successfully')
      else
      render_error(
      message: 'Failed to create schedule',
      code: 'VALIDATION_ERROR',
      status: :unprocessable_entity,
      details: schedule.errors.as_json
      )
      end
      end
      
      def update
      old_values = @schedule.attributes.dup
      
      if @schedule.update(schedule_params)
      log_user_action(
      action: 'update',
      entity_type: 'Schedule',
      entity_id: @schedule.id,
      old_values: old_values,
      new_values: @schedule.attributes
      )
      
      render_updated({
      schedule: ScheduleSerializer.render_as_hash(@schedule)
      })
      else
      render_error(
      message: 'Failed to update schedule',
      code: 'VALIDATION_ERROR',
      status: :unprocessable_entity,
      details: @schedule.errors.as_json
      )
      end
      end
      
      def destroy
      if @schedule.destroy
      log_user_action(
      action: 'delete',
      entity_type: 'Schedule',
      entity_id: @schedule.id,
      old_values: @schedule.attributes
      )
      
      render_deleted(message: 'Event deleted successfully')
      else
      render_error(
      message: 'Failed to delete schedule',
      code: 'DELETE_ERROR',
      status: :unprocessable_entity
      )
      end
      end
      
      private
      
      def set_schedule
      @schedule = organization_scoped(Schedule).find(params[:id])
      end
      
      def schedule_params
      params.require(:schedule).permit(
      :event_type, :title, :description,
      :start_time, :end_time, :location,
      :opponent_name, :status, :match_id,
      :meeting_url, :all_day, :timezone,
      :color, :is_recurring, :recurrence_rule,
      :recurrence_end_date, :reminder_minutes,
      required_players: [], optional_players: [], tags: []
      )
      end
      end
  end
end
