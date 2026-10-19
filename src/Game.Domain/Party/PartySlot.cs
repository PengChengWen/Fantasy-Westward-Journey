namespace Game.Domain.Party;

/// <summary>A character and its optional, exclusively assigned active pet.</summary>
public sealed record PartySlot(string CharacterId, string? PetInstanceId = null);
