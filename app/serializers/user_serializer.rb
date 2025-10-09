# app/serializers/user_serializer.rb
class UserSerializer
  def initialize(user)
    @user = user
  end

  def to_json(*_args)
    {
      id: @user.id,
      email: @user.email,
      first_name: @user.first_name,
      last_name: @user.last_name,
      full_name: @user.full_name,
      locale: @user.locale,
      admin: @user.admin?,
      company: company_data,
      membership: membership_data
    }
  end

  private

  def company_data
    return nil unless @user.current_company

    CompanySerializer.new(@user.current_company).as_json
  end

  def membership_data
    return nil unless @user.current_membership

    {
      role: @user.current_membership.role,
      scopes: @user.current_membership.scopes || []
    }
  end
end
