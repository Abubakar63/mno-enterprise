require 'rails_helper'

module MnoEnterprise
  RSpec.describe User, type: :model do
    def reload_user
      # Reload User class to redefine the validation
      # Removes MnoEnterprise::User from object-space:
      MnoEnterprise.send(:remove_const, :User)
      # Reloads the module (require might also work):
      load 'app/models/mno_enterprise/user.rb'
    end

    describe 'password strength' do
      let(:user) do
        # Initialize this way so the class reload is taken into account (the factory doesnt reload the User class)
        MnoEnterprise::User.new(attributes_for(:user, password: 'password')).tap {|u| u.clear_attribute_changes!}
      end

      context 'without password regex' do
        it 'does not validate the password strength' do
          expect(user).to be_valid
        end
      end

      context 'with password regex' do
        before do
          Devise.password_regex = /(?=.*\d)(?=.*[a-z])(?=.*[A-Z])/
          reload_user
        end

        it 'validates the password strength' do
          expect(user).to be_invalid
          expect(user.errors[:password].first).to eq('must contains at least one uppercase letter, one lower case letter and a number')
        end

        after do
          # Reset to default
          Devise.password_regex = nil
          MnoEnterprise.send(:remove_const, :User)
          load 'app/models/mno_enterprise/user.rb'
        end
      end
    end

    describe 'IntercomUser' do
      context 'without Intercom' do
        # default
        let(:user) { MnoEnterprise::User.new(email: 'admin@example.com') }

        describe :intercom_data do
          it { expect(user).not_to respond_to(:intercom_data) }
        end

        describe :intercom_user_hash do
          it { expect(user).not_to respond_to(:intercom_user_hash) }
        end
      end

      context 'with Intercom' do
        before do
          allow(MnoEnterprise).to receive(:intercom_enabled?).and_return(true)
          allow(MnoEnterprise).to receive(:intercom_api_secret).and_return('mysecret')

          # Reload User class to include IntercomUser concern
          MnoEnterprise.send(:remove_const, :User)
          load 'app/models/mno_enterprise/user.rb'
        end
        after do
          # Reset to default
          MnoEnterprise.send(:remove_const, :User)
          load 'app/models/mno_enterprise/user.rb'
        end

        let(:user) { MnoEnterprise::User.new(attributes_for(:user, admin_role: 'admin')) }

        describe :intercom_user_hash do
          it 'returns the user intercom secure hash' do
            expect(user.intercom_user_hash).not_to be_nil
          end
        end

        describe :intercom_data do
          let(:expected) {
            {
              user_id: user.id,
              name: [user.name, user.surname].join(' '),
              email: user.email,
              created_at: user.created_at.to_i,
              last_seen_ip: user.last_sign_in_ip,
              custom_attributes: {
                first_name: user.name,
                surname: user.surname,
                confirmed_at: user.confirmed_at,
                phone: user.phone,
                admin_role: user.admin_role
              },
              update_last_request_at: true
            }
          }

          it {
            expect(user.intercom_data).to eq(expected)
          }
        end
      end
    end

    describe 'Omniauth' do
      let(:firstname) { "Jack" }
      let(:lastname) { "Beauregard" }
      let(:provider) { 'someprovider' }
      let(:auth) { OmniAuth::AuthHash.new(
        {
          provider: provider,
          uid: '123545',
          info: {
            first_name: firstname,
            last_name: lastname,
            email: 'jack.beauregard@maestrano.com'
          }
        }
      ) }


      describe '.find_for_oauth' do
        it { expect(described_class).to respond_to(:find_for_oauth) }

        subject { described_class.find_for_oauth(auth) }

        context 'without a signed in user' do

          context 'with a matching identity' do
            let(:user) { build(:user, email: auth.info.email) }
            let(:identity) { build(:identity, provider: auth.provider, uid: auth.uid, user: user.attributes) }

            before { expect(Identity).to receive(:find_for_oauth) { identity } }

            it 'returns the matching user' do
              expect(subject).to eq(user)
            end

            it 'does not create a new user' do
              expect(described_class).not_to receive(:create_from_omniauth)
              subject
            end
          end

          context 'with no matching identity' do
            let(:identity) { build(:identity, provider: auth.provider, uid: auth.uid) }
            before { expect(Identity).to receive(:find_for_oauth) { identity } }

            context 'when a user with a matching email exists' do
              let(:user) { build(:user, email: auth.info.email) }
              before do
                api_stub_for(get: "/users", params: {filter: {email: auth.info.email}}, response: from_api([user]))
                api_stub_for(post: "/identities", response: from_api(identity))
              end

              it 'associates the new identity with the user' do
                subject
                expect(identity.user_id).to eq(user.id)
              end

              it 'returns the matching user' do
                expect(subject).to eq(user)
              end

              it 'does not create a new user' do
                expect(described_class).not_to receive(:create_from_omniauth)
                subject
              end

              context 'with Intuit provider' do
                let(:provider) { 'intuit' }

                context 'when email is authorised' do
                  subject { described_class.find_for_oauth(auth, authorized_link_to_email: auth[:info][:email]) }
                  it 'does not raise an error' do
                    expect { subject }.not_to raise_error
                  end
                end

                context 'when email is not authorised' do
                  it 'raises an error' do
                    expect { subject }.to raise_error(SecurityError, 'reconfirm credentials')
                  end
                end
              end
            end

            context 'when no user with a matching email exists' do
              let(:user) { described_class.new }
              let(:identity) { build(:identity, provider: auth.provider, uid: auth.uid) }

              before do
                api_stub_for(get: "/users", params: {filter: {email: auth.info.email}}, response: from_api(nil))
                api_stub_for(post: "/identities", response: from_api(identity))
              end

              it 'creates and returns a new user' do
                expect(described_class).to receive(:create_from_omniauth).with(auth, {}).and_return(user)
                expect(subject).to eq(user)
              end
            end
          end
        end

        context 'with a signed in user' do
          let(:user) { FactoryGirl.build(:user) }
          subject { described_class.find_for_oauth(auth, {}, user) }

          context 'when the identity match the current user' do
            let(:identity) { build(:identity, provider: auth.provider, uid: auth.uid, user: user.attributes) }
            before { expect(Identity).to receive(:find_for_oauth) { identity } }

            it 'does not touch the identity' do
              # no stub
              subject
            end

            it 'returns the current user' do
              expect(subject).to eq(user)
            end

            it 'does not create a new user' do
              expect(described_class).not_to receive(:create_from_omniauth)
              subject
            end
          end

          context 'when the identity does not match the current user' do
            let(:identity) { build(:identity, provider: auth.provider, uid: auth.uid) }
            before { expect(Identity).to receive(:find_for_oauth) { identity } }

            before do
              api_stub_for(post: "/identities", response: from_api(identity))
            end

            it 're-assign the identity to the current user' do
              subject
              expect(identity.user_id).to eq(user.id)
            end

            it 'returns the current user' do
              expect(subject).to eq(user)
            end

            it 'does not create a new user' do
              expect(described_class).not_to receive(:create_from_omniauth)
              subject
            end
          end
        end
      end

      describe '.create_from_omniauth' do
        let(:user) { build(:user) }

        before do
          allow(MnoEnterprise::User).to receive(:new) { user }
          allow(user).to receive(:save) { user }
        end

        subject { described_class.create_from_omniauth(auth) }

        it { expect(described_class).to respond_to(:create_from_omniauth) }

        it 'creates a new user with the proper fields' do
          expect(MnoEnterprise::User).to receive(:new).with(
            hash_including(
              name: auth.info.first_name,
              surname: auth.info.last_name,
              email: auth.info.email
            )).and_return(user)
          subject
        end

        it 'skips email confirmation' do
          expect(user).to receive(:skip_confirmation!)
          expect(subject).to be_confirmed
        end

        context 'with Intuit provider' do
          let(:provider) { 'intuit' }

          it 'does not skip email confirmation' do
            expect(user).not_to receive(:skip_confirmation!)
            subject
          end
        end

        context 'with some params' do
          let(:comp_name) { 'some company to be set' }
          subject { described_class.create_from_omniauth(auth, company: comp_name) }

          it 'creates a user with correct attributes' do
            expect(subject.company).to eq(comp_name)
          end
        end

        context 'when omniauth provides a user with no name' do
          let(:firstname) { nil }
          let(:lastname) { nil }

          it "creates a user with name='first_part_of_email' and surname=''" do
            expect(MnoEnterprise::User).to receive(:new).with(
              hash_including(
                name: 'jack.beauregard',
                surname: '',
                email: auth.info.email
              )).and_return(user)
            subject
          end
        end
      end
    end

    describe 'Devise' do
      subject { MnoEnterprise::User.new }
      describe 'registerable?' do
        context 'default' do
          before { reload_user }
          it 'is registerable' do
            expect(MnoEnterprise::User.ancestors).to include(Devise::Models::Registerable)
          end
        end

        context 'enabled' do
          before do
            Settings.merge!(devise: { registration: { disabled: false } })
            reload_user
          end
          it 'is registerable' do
            expect(MnoEnterprise::User.ancestors).to include(Devise::Models::Registerable)
          end
        end

        context 'disabled' do
          before do
            Settings.merge!(devise: { registration: { disabled: true } })
            reload_user
          end
          it 'is not registerable' do
            expect(MnoEnterprise::User.ancestors).not_to include(Devise::Models::Registerable)
          end
        end
      end
    end
  end
end
