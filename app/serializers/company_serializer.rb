# app/serializers/company_serializer.rb
class CompanySerializer
  def initialize(company)
    @company = company
  end

  def as_json
    return nil unless @company

    {
      id: @company.id,
      code: @company.code,
      name: @company.name,
      logo_code: @company.logo_code,
      vat_id: @company.vat_id,
      email: @company.email,
      phone: @company.phone,
      locale: @company.locale,
      info: @company.info || {}
    }
  end

  def to_json(*_args)
    as_json.to_json
  end
end
