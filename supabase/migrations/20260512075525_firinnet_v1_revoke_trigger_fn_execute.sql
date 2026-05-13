-- Migration: firinnet_v1_revoke_trigger_fn_execute
-- Version: 20260512075525
-- Source: applied to remote project sjeqwiqgwzagengdukye via MCP apply_migration on 2026-05-12
-- This file is a local mirror for source control. DO NOT re-apply to remote;
-- remote already records this version.

-- Trigger function'larin RPC uzerinden anon/authenticated tarafindan calistirilmasi engellenir.
-- Bunlar yalniz dahili trigger context'inde calismalidir.

revoke all on function public.trg_dealer_delivery_items_recalc() from public;
revoke all on function public.trg_dealer_delivery_items_recalc() from anon;
revoke all on function public.trg_dealer_delivery_items_recalc() from authenticated;

-- recalculate_dealer_delivery_totals zaten ilk migration'da revoke edildi
-- ancak emin olmak icin tekrar uygula (idempotent)
revoke all on function public.recalculate_dealer_delivery_totals(uuid) from public;
revoke all on function public.recalculate_dealer_delivery_totals(uuid) from anon;
revoke all on function public.recalculate_dealer_delivery_totals(uuid) from authenticated;
