namespace Game.Domain.Party;

public static class PartyRules
{
    public const int MaxCharacters = 5;
    public const int MaxPetsPerCharacter = 1;
    public const int MaxFriendlyUnits = MaxCharacters * (1 + MaxPetsPerCharacter);

    public static IReadOnlyList<string> Validate(IReadOnlyList<PartySlot> slots)
    {
        ArgumentNullException.ThrowIfNull(slots);
        var errors = new List<string>();
        var characters = new HashSet<string>(StringComparer.Ordinal);
        var pets = new HashSet<string>(StringComparer.Ordinal);

        if (slots.Count is < 1 or > MaxCharacters)
        {
            errors.Add("party.character_count");
        }

        foreach (var slot in slots)
        {
            if (string.IsNullOrWhiteSpace(slot.CharacterId))
            {
                errors.Add("party.character_id_required");
            }
            else if (!characters.Add(slot.CharacterId))
            {
                errors.Add("party.duplicate_character");
            }

            if (slot.PetInstanceId is null)
            {
                continue;
            }

            if (string.IsNullOrWhiteSpace(slot.PetInstanceId))
            {
                errors.Add("party.pet_id_required");
            }
            else if (!pets.Add(slot.PetInstanceId))
            {
                errors.Add("party.pet_already_assigned");
            }
        }

        return errors;
    }
}
