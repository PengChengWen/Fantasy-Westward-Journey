namespace Game.Application.Abstractions;

/// <summary>Optional platform capabilities; game rules must not require Steam.</summary>
public interface IPlatformServices
{
    string PlatformId { get; }
    bool SupportsAchievements { get; }
}
