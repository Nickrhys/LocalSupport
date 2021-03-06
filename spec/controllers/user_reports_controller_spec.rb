require 'rails_helper'
describe UserReportsController, :type => :controller do
  describe 'PUT update user-organisation status', :helpers => :controllers do
    before(:each) do
      make_current_user_superadmin
      @nonadmin_user = double("User")
      allow(User).to receive(:find_by_id).with("4").and_return(@nonadmin_user)
      allow(@nonadmin_user).to receive(:pending_organisation_id=).with('5')
      allow(@nonadmin_user).to receive(:save!)
      @org = double("Organisation")
      allow(@org).to receive(:name).and_return('Red Cross')
      allow(Organisation).to receive(:find).and_return(@org)
    end
    context 'user requesting pending status to be admin of charity' do
      before do
        allow(@nonadmin_user).to receive(:request_admin_status)
        allow(@nonadmin_user).to receive(:promote_to_org_admin)
        allow(@nonadmin_user).to receive(:email)
      end

      it 'should redirect to the show page for nested org' do
        put :update, id: 4, organisation_id: 5
        expect(response).to redirect_to(organisation_path(5))
      end
      it 'should display that a user has requested admin status for nested org' do
        put :update, id: 4, organisation_id: 5
        expect(flash[:notice]).to have_content("You have requested admin status for #{@org.name}")
      end
    end
    context 'superadmin promoting user to charity admin' do
      before(:each) do
        allow(@nonadmin_user).to receive(:promote_to_org_admin)
        allow(@nonadmin_user).to receive(:email).and_return('stuff@stuff.com')
      end
      it 'non-superadmins get refused' do
        allow(@nonsuperadmin_user).to receive(:superadmin?).and_return(false)
        allow(controller).to receive(:current_user).and_return(@nonsuperadmin_user)
        put :update, {:id => '4'}
        expect(response.response_code).to eq(404)
      end

      it 'redirect to index page after update succeeds' do
        put :update, {:id => '4'}
        expect(response).to redirect_to users_report_path
      end
      it 'shows a flash telling which user got approved' do
        put :update, {:id => '4'}
        expect(flash[:notice]).to have_content("You have approved #{@nonadmin_user.email}.")
      end
    end
  end

  describe 'DELETE destroy', :helpers => :controllers do
    let!(:user) { create :user }

    it 'destroys the user' do
      make_current_user_superadmin
      expect{
        delete :destroy, id: user.id
      }.to change(User, :count).by -1
    end

    it 'unless that user is the current_user' do
      make_current_user_superadmin(user)
      expect{
        delete :destroy, id: user.id
      }.not_to change(User, :count)
    end
  end

  describe 'GET index to view pending users' do
    context "user signed in", :helpers => :controllers do
      context "as superadmin" do
        before(:each) do
          make_current_user_superadmin
        end

        it "assigns all users to @users" do
          user_double = double("User")
          allow(User).to receive(:all).and_return([user_double])
          get :index
          expect(assigns(:users)).to eql([user_double])
        end

        it "renders the index template" do
          get :index
          expect(response).to render_template('index')
        end

        it "renders in full width" do
          get :index
          expect(response).to render_template('layouts/full_width')
        end
      end

      context "as non-superadmin" do
        before(:each) do
          make_current_user_nonsuperadmin
        end

        it "redirects user to root and flashes a notice" do
          get :index
          expect(response).to redirect_to root_path
        end

        it "flashes the relevant notice" do
          get :index
          expect(flash[:error]).to have_content("You must be signed in as a superadmin to perform this action!")
        end
      end
    end

    context "user not signed in" do
      before(:each) do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      it "redirects user to root" do
        get :index
        expect(response).to redirect_to root_path
      end

      it "flashes the relevant notice" do
        get :index
        expect(flash[:error]).to have_content("You must be signed in as a superadmin to perform this action!")
      end

    end
  end

  describe 'GET invited users report', :helpers => :controllers do
    let(:organisation) do
      double :organisation, {
          id: '-1',
          name: 'sample org',
      }
    end

    let(:user) do
      double :user, {
          organisation: organisation,
          email: 'user@email.org',
          invitation_sent_at: 'date-time-thingy'
      }
    end

    before do
      make_current_user_superadmin
      allow(User).to receive(:invited_not_accepted) { [user] }
    end

    it 'is for superadmins only' do
      make_current_user_nonsuperadmin
      get :invited
      expect(response).to redirect_to root_path
    end

    it 'uses the invited template and the invitation table layout' do
      get :invited
      expect(response).to render_template 'user_reports/invited'
      expect(response).to render_template 'layouts/invitation_table'
    end

    it 'assigns true to @resend_invitation' do
      get :invited
      expect(assigns(:resend_invitation)).to be true
    end

    it 'assigns serialized invitations to @invitations' do
      expect(User).to receive(:invited_not_accepted) { [user] }
      get :invited
      expect(assigns(:invitations)).to eq([{
                                               :id => '-1',
                                               :name => 'sample org',
                                               :email => 'user@email.org',
                                               :date => 'date-time-thingy'
                                           }])
    end

  end
end
