# frozen_string_literal: true

# Security headers para o perimetro publico da API.
# O frontend (prostaff.gg) ja esta coberto pelo Cloudflare.
# Aqui cobrimos api.prostaff.gg que e servido direto via Traefik.
#
# Usamos merge! para preservar os defaults do Rails

Rails.application.config.action_dispatch.default_headers.merge!(

  'X-Frame-Options'           => 'DENY',


  'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',

  # API JSON nao renderiza HTML — CSP minimo bloqueia qualquer tentativa
  'Content-Security-Policy'   => "default-src 'none'; frame-ancestors 'none'",

  # Desabilita features de browser que uma API nao usa
  'Permissions-Policy'        => 'geolocation=(), camera=(), microphone=(), payment=()'
)
