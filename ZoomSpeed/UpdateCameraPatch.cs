using HarmonyLib;

namespace ZoomSpeed;

[HarmonyPatch(typeof(GameCamera), nameof(GameCamera.UpdateCamera))]
internal static class UpdateCameraPatch
{
    private static float _vanillaZoomSens;

    private static void Prefix(GameCamera __instance)
    {
        if (_vanillaZoomSens == 0f)
        {
            _vanillaZoomSens = __instance.m_zoomSens;
        }

        __instance.m_zoomSens = _vanillaZoomSens * ZoomSpeed.ScrollMultiplier.Value;
    }
}
