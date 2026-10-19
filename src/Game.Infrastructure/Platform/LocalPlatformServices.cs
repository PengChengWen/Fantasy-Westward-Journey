using Game.Application.Abstractions;

namespace Game.Infrastructure.Platform;

public sealed class LocalPlatformServices : IPlatformServices
{
    public string PlatformId => "local";
    public bool SupportsAchievements => false;
}
