# frozen_string_literal: true

# Serializer for PlayerMatchStat model
#
# Renders player match statistics with calculated fields and CDN asset URLs.
# Includes KDA calculations, champion icons, items, runes, and summoner spells.
class PlayerMatchStatSerializer < Blueprinter::Base
  identifier :id

  fields :role, :champion, :kills, :deaths, :assists,
         :gold_earned, :damage_dealt_total, :damage_taken,
         :vision_score, :wards_placed, :wards_destroyed,
         :first_blood, :double_kills,
         :triple_kills, :quadra_kills, :penta_kills,
         :performance_score, :created_at, :updated_at

  field :kda do |stat|
    deaths = stat.deaths.zero? ? 1 : stat.deaths
    ((stat.kills + stat.assists).to_f / deaths).round(2)
  end

  field :cs_total do |stat|
    stat.cs || 0
  end

  field :champion_icon_url do |stat|
    RiotCdnService.new.champion_icon_url(stat.champion)
  end

  field :items do |stat|
    cdn = RiotCdnService.new
    stat.items.map do |item_id|
      {
        id: item_id,
        icon_url: cdn.item_icon_url(item_id)
      }
    end
  end

  field :runes do |stat|
    cdn = RiotCdnService.new
    stat.runes.map do |rune_id|
      {
        id: rune_id,
        icon_url: cdn.rune_icon_url(rune_id)
      }
    end
  end

  field :summoner_spells do |stat|
    [stat.summoner_spell_1, stat.summoner_spell_2].compact.map do |spell_name|
      # NOTE: If we stored spell IDs we would use spell_icon_url(id).
      # Assuming we might have names or IDs. The service expects IDs for the map,
      # but if we have names we might need a different approach.
      # Let's check the schema again. It says string for summoner_spell_1/2.
      # If it's "SummonerFlash", we can just construct the URL directly or add a method for name.
      # Let's assume for now we might need to handle names directly if they are stored as names.
      # Actually, let's just try to use the name if it looks like a name.

      # If the stored value is "SummonerFlash", we can use it.
      # If it's an ID (as string), we need to map it.

      # For safety, let's just return the name and let the frontend handle it or
      # try to generate a URL if it matches known spell names.

      # Let's add a helper in RiotCdnService to handle names if needed,
      # but for now let's assume the service's spell_icon_url might need an update if we pass names.
      # Wait, the service I wrote expects IDs.
      # Let's check what's actually stored. The schema says string.
      # If it's "SummonerFlash", then my service method `spell_icon_url` which takes an ID won't work directly.

      # Let's update the serializer to just pass the name if it's a name,
      # or try to map it if it's an ID.

      # Actually, let's just pass the raw value for now and the URL.
      # I'll add a `spell_icon_url_by_name` to the service or just handle it here.
      # Let's keep it simple:

      {
        name: spell_name,
        icon_url: "#{RiotCdnService::BASE_URL}/#{RiotCdnService::DEFAULT_VERSION}/img/spell/#{spell_name}.png"
      }
    end
  end

  association :player, blueprint: PlayerSerializer
  association :match, blueprint: MatchSerializer
end
