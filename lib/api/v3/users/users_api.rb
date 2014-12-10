#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2014 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

module API
  module V3
    module Users
      class UsersAPI < Grape::API
        resources :users do

          params do
            requires :id, desc: 'User\'s id'
          end
          namespace ':id' do

            before do
              @user  = User.find(params[:id])
            end

            get do
              UserRepresenter.new(@user)
            end

            delete do
              unless DeleteUser.deletion_allowed? @user, current_user
                fail ::API::Errors::Unauthorized
              end

              @user.lock! # lock user to disable them until completely deleted
              UsersAPI.delete_user @user, current_user
              User.current = nil if @user == current_user # log out if deleted oneself

              status 202
            end
          end

        end

        def self.delete_user(user, actor)
          Delayed::Job.enqueue DeleteUserJob.new(user, actor)
        end
      end
    end
  end
end
