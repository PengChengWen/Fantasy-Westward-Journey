using Game.Domain.Party;
using Xunit;

namespace Game.Domain.Tests;

public sealed class PartyRulesTests
{
    [Fact]
    public void FiveCharactersWithDistinctPetsAreValid()
    {
        var party = Enumerable.Range(1, 5)
            .Select(index => new PartySlot($"character_{index}", $"pet_{index}"))
            .ToArray();

        Assert.Empty(PartyRules.Validate(party));
    }

    [Fact]
    public void SamePetCannotBeAssignedToDifferentOwners()
    {
        PartySlot[] party = [new("one", "shared_pet"), new("two", "shared_pet")];

        Assert.Contains("party.pet_already_assigned", PartyRules.Validate(party));
    }

    [Fact]
    public void SameCharacterCannotOccupyTwoSlots()
    {
        PartySlot[] party = [new("same", "pet_one"), new("same", "pet_two")];

        Assert.Contains("party.duplicate_character", PartyRules.Validate(party));
    }

    [Fact]
    public void PetsAreOptional()
    {
        Assert.Empty(PartyRules.Validate([new PartySlot("character")]));
    }

    [Fact]
    public void SixCharactersExceedTheRosterLimit()
    {
        var party = Enumerable.Range(1, 6)
            .Select(index => new PartySlot($"character_{index}"))
            .ToArray();

        Assert.Contains("party.character_count", PartyRules.Validate(party));
    }

    [Fact]
    public void EmptyPartyCannotStartABattle()
    {
        Assert.Contains("party.character_count", PartyRules.Validate([]));
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    public void AssignedPetMustHaveANonblankInstanceId(string petId)
    {
        Assert.Contains("party.pet_id_required", PartyRules.Validate([new PartySlot("one", petId)]));
    }
}
