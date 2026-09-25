# frozen_string_literal: true

# One enterprise fee on a variant, as a read only value for the view.
ViewData::Fee = Data.define(:name, :enterprise_name, :fee_type, :amount)
