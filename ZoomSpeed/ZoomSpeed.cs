using BepInEx;
using BepInEx.Configuration;
using BepInEx.Logging;
using HarmonyLib;

namespace ZoomSpeed;

[BepInPlugin(PluginGUID, PluginName, PluginVersion)]
internal class ZoomSpeed : BaseUnityPlugin
{
    public const string PluginGUID = "orax.ZoomSpeed";
    public const string PluginName = "ZoomSpeed";
    public const string PluginVersion = "0.1.0";

    internal static ManualLogSource Log;
    internal static ConfigEntry<float> ScrollMultiplier;
    private Harmony _harmony;

    private void Awake()
    {
        Log = base.Logger;
        Log.LogInfo("ZoomSpeed has landed");

        ScrollMultiplier = Config.Bind(
            "Zoom",
            "ScrollMultiplier",
            2f,
            new ConfigDescription(
                "Mouse wheel zoom speed multiplier (1 = vanilla).",
                new AcceptableValueRange<float>(0.1f, 10f)
            )
        );

        _harmony = new Harmony(PluginGUID);
        _harmony.PatchAll();
    }

    private void OnDestroy()
    {
        _harmony?.UnpatchSelf();
    }
}
