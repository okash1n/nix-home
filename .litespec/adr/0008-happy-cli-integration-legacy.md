# ADR 0008: Happy CLI 導入方針（旧運用）

- Status: Superseded
- Date: 2026-02-11
- Superseded Date: 2026-03-04

## Context

- 以前は AI CLI を Nix 側でまとめて導入していた。
- 当時の方針では、グローバル直インストールを避け、設定配置を XDG に統一する必要があった。

## Decision

- Happy CLI を Nix 管理で導入し、`HAPPY_HOME_DIR` を `~/.config/happy` に固定した。
- 旧パス誤利用の検知として `~/.happy` に番兵ファイルを配置した。

## Consequences

- 当時は再現可能性を優先した運用ができた。
- 一方で、更新速度が求められる CLI の追従には運用コストが残った。

## Superseded Notes

- 2026-03-04 時点で、AI CLI は Homebrew / npm / ローカルバイナリ中心の運用へ移行した。
