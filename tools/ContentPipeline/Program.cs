using System.Security.Cryptography;
using System.Text.Json;
using Game.Domain.Party;

if (args.Length != 1)
{
    Console.Error.WriteLine("Usage: ContentPipeline <bootstrap.json>");
    return 2;
}

try
{
    var bytes = File.ReadAllBytes(args[0]);
    using var document = JsonDocument.Parse(bytes);
    var root = document.RootElement;
    if (root.GetProperty("schemaVersion").GetInt32() != 1)
    {
        throw new InvalidDataException("Unsupported bootstrap schema.");
    }

    var party = root.GetProperty("party");
    if (party.GetProperty("maxCharacters").GetInt32() != PartyRules.MaxCharacters ||
        party.GetProperty("maxPetsPerCharacter").GetInt32() != PartyRules.MaxPetsPerCharacter)
    {
        throw new InvalidDataException("Party configuration disagrees with domain rules.");
    }

    var ids = new HashSet<string>(StringComparer.Ordinal);
    foreach (var sect in root.GetProperty("sects").EnumerateArray())
    {
        var id = sect.GetProperty("id").GetString();
        var name = sect.GetProperty("name").GetString();
        if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(name) || !ids.Add(id))
        {
            throw new InvalidDataException("Sect IDs and names are required; IDs must be unique.");
        }
    }

    if (ids.Count == 0)
    {
        throw new InvalidDataException("At least one sect must be defined.");
    }

    Console.WriteLine(JsonSerializer.Serialize(new
    {
        schemaVersion = 1,
        sectCount = ids.Count,
        maxFriendlyUnits = PartyRules.MaxFriendlyUnits,
        sha256 = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant()
    }));
    return 0;
}
catch (Exception exception) when (exception is IOException or InvalidDataException or JsonException or
    KeyNotFoundException or InvalidOperationException or FormatException or OverflowException)
{
    Console.Error.WriteLine($"Content validation failed: {exception.Message}");
    return 1;
}
