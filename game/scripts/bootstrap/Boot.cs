using Game.Application.Abstractions;
using Game.Infrastructure.Platform;
using Godot;

namespace Game.Client.Bootstrap;

/// <summary>Composition root only. Gameplay and production UI are not implemented yet.</summary>
public partial class Boot : Node
{
    public override void _Ready()
    {
        IPlatformServices platform = new LocalPlatformServices();
        GD.Print($"照夜山海：工程骨架启动，平台={platform.PlatformId}。战斗尚未实现。");
    }
}
