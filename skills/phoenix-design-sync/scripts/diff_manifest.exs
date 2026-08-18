# Diffs the local design-sync manifest against a freshly fetched upstream _ds_sync.json.
# Prints a single JSON object to stdout (see references/manifest-format.md).
#
#   elixir diff_manifest.exs <manifest.json|-> <upstream_ds_sync.json> [app_root]
#
# Pass "-" (or a nonexistent path) as the manifest on first run.

defmodule DesignSync.Diff do
  def main([manifest_path, upstream_path | rest]) do
    app_root = List.first(rest) || "."

    upstream = decode_file!(upstream_path)
    manifest = read_manifest(manifest_path)

    upstream_components = parse_source_hashes(upstream["sourceHashes"] || %{})
    local_components = parse_local_components(manifest["components"] || %{})

    upstream_keys = MapSet.new(Map.keys(upstream_components))
    local_keys = MapSet.new(Map.keys(local_components))

    added = MapSet.difference(upstream_keys, local_keys)
    removed = MapSet.difference(local_keys, upstream_keys)

    changed =
      for key <- MapSet.intersection(upstream_keys, local_keys),
          upstream_components[key] != local_components[key],
          do: key

    unchanged =
      MapSet.intersection(upstream_keys, local_keys) |> MapSet.size() |> Kernel.-(length(changed))

    result = %{
      "first_run" => manifest == %{},
      "style_changed" => manifest == %{} or manifest["styleSha"] != upstream["styleSha"],
      "added" => added |> Enum.sort(),
      "changed" => Enum.sort(changed),
      "removed" => removed |> Enum.sort(),
      "drifted" => drifted(manifest["fileShas"] || %{}, app_root),
      "unchanged" => unchanged,
      "upstream_components" => upstream_components
    }

    IO.puts(encode!(result))
  end

  def main(_argv) do
    IO.puts(:stderr, "usage: elixir diff_manifest.exs <manifest.json|-> <upstream_ds_sync.json> [app_root]")
    System.halt(2)
  end

  defp read_manifest("-"), do: %{}

  defp read_manifest(path) do
    if File.exists?(path), do: decode_file!(path), else: %{}
  end

  # "components/<group>/<Name>/<file>" hashes -> %{"group/Name" => %{"jsx"|"dts"|"prompt" => hash}}
  defp parse_source_hashes(source_hashes) do
    Enum.reduce(source_hashes, %{}, fn {path, hash}, acc ->
      case String.split(path, "/") do
        ["components", group, name, file] ->
          kind =
            cond do
              String.ends_with?(file, ".d.ts") -> "dts"
              String.ends_with?(file, ".prompt.md") -> "prompt"
              String.ends_with?(file, ".jsx") or String.ends_with?(file, ".tsx") -> "jsx"
              true -> nil
            end

          if kind,
            do: Map.update(acc, "#{group}/#{name}", %{kind => hash}, &Map.put(&1, kind, hash)),
            else: acc

        _other ->
          acc
      end
    end)
  end

  defp parse_local_components(components) do
    Map.new(components, fn {key, entry} -> {key, entry["sourceHashes"] || %{}} end)
  end

  defp drifted(file_shas, app_root) do
    file_shas
    |> Enum.flat_map(fn {rel_path, recorded_sha} ->
      full = Path.join(app_root, rel_path)

      case File.read(full) do
        {:ok, content} ->
          current = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
          if current == recorded_sha, do: [], else: [%{"path" => rel_path, "reason" => "modified"}]

        {:error, _} ->
          [%{"path" => rel_path, "reason" => "missing"}]
      end
    end)
    |> Enum.sort_by(& &1["path"])
  end

  # Elixir >= 1.18 has the built-in JSON module; fall back to Jason for older runtimes.
  if Code.ensure_loaded?(JSON) do
    defp decode_file!(path), do: path |> File.read!() |> JSON.decode!()
    defp encode!(term), do: JSON.encode!(term)
  else
    Mix.install([{:jason, "~> 1.4"}])
    defp decode_file!(path), do: path |> File.read!() |> Jason.decode!()
    defp encode!(term), do: Jason.encode!(term)
  end
end

DesignSync.Diff.main(System.argv())
