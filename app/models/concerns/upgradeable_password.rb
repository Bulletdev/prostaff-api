# frozen_string_literal: true

module UpgradeablePassword
  extend ActiveSupport::Concern

  # Verifies plain_password against the stored digest and, if the digest still
  # uses bcrypt, transparently re-hashes with Argon2id on the same request.
  #
  # @param plain_password [String] the password to verify
  # @param digest_attr [Symbol] the attribute name holding the stored digest
  # @param digest_setter [Symbol] the column name to write the upgraded digest
  # @return [self, nil] returns self on success, nil on failure
  def authenticate_with_upgrade(plain_password, digest_attr:, digest_setter:)
    digest = send(digest_attr)
    return nil unless Authentication::PasswordHasher.verify(plain_password, digest)

    if Authentication::PasswordHasher.needs_upgrade?(digest)
      new_digest = Authentication::PasswordHasher.hash(plain_password)
      # Two separate update_column calls instead of update_columns so that Rails
      # dirty tracking is cleared field-by-field — avoids unexpected behavior on
      # read-replica setups where a bulk UPDATE could interleave with pending reads.
      # update_column bypasses callbacks intentionally (no before_save/after_save
      # during a transparent hash upgrade).
      update_column(digest_setter, new_digest)
      update_column(:updated_at, Time.current)
    end

    self
  end
end
