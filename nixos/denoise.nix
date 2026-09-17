{ pkgs, ... }:

# Шумодав микрофона: DeepFilterNet в filter-chain самого PipeWire, без фоновых программ.
# Умный фильтр WirePlumber встаёт перед микрофоном по умолчанию и переезжает вместе с ним
# (встроенный ↔ внешний); приложения берут микрофон по умолчанию и получают очищенный звук.
# Задержка ≈ 20 мс модели + квант PipeWire
{
  services.pipewire.extraConfig.pipewire."90-denoise" = {
    "context.modules" = [{
      name = "libpipewire-module-filter-chain";
      args = {
        "node.description" = "Шумодав (DeepFilterNet)";
        "media.name" = "Шумодав (DeepFilterNet)";
        "filter.graph".nodes = [{
          type = "ladspa";
          name = "deepfilter";
          plugin = "${pkgs.deepfilternet}/lib/ladspa/libdeep_filter_ladspa.so";
          label = "deep_filter_mono";
          # 100 — давить шум полностью; если голос «плывёт» — 18–24 (средне), 6–12 (слабо)
          control."Attenuation Limit (dB)" = 100;
        }];
        "audio.rate" = 48000; # модель работает только на 48 кГц
        "audio.position" = [ "MONO" ];
        # ключи с точкой — в кавычках: PipeWire ждёт "capture.props", а не вложенный capture.props
        "capture.props" = {
          "node.passive" = true; # микрофон не держится открытым, пока никто не пишет
        };
        "playback.props" = {
          "media.class" = "Audio/Source";
          # главный узел фильтра — не Stream/*, поэтому свойства умного фильтра здесь
          "filter.smart" = true;
          "filter.smart.name" = "denoise";
        };
      };
    }];
  };
}
