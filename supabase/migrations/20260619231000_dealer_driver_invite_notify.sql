-- Bayi Yönetimi — Şoförler · Sprint 6 (ek): davet bildirimi (additive trigger).
--
-- Şoför daveti oluşunca davet edilen kullanıcıya in-app bildirim düşer (mevcut
-- notifications merkezi). Böylece şoför, henüz aktif bağlantısı (dealer_drivers)
-- olmadan daveti keşfedip /dealers'tan kabul/ret yapabilir.
--
-- Güvenlik/anonimlik: actor_id NULL + generic metin (kişisel bilgi yok). INSERT
-- yalnız definer trigger (notifications INSERT policy yok). EXECUTE revoke.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

create or replace function public.notify_dealer_driver_invite()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.invited_user_id is distinct from new.owner_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values
      (new.invited_user_id, null, 'dealer_driver_invite_created',
       'Şoför daveti aldın', 'Bir işletme seni şoför olarak eklemek istiyor.',
       'dealer_driver_invite', new.id, '/dealers');
  end if;
  return new;
end;
$$;
revoke execute on function public.notify_dealer_driver_invite()
  from public, anon, authenticated;

drop trigger if exists trg_notify_dealer_driver_invite on public.dealer_driver_invites;
create trigger trg_notify_dealer_driver_invite
  after insert on public.dealer_driver_invites
  for each row execute function public.notify_dealer_driver_invite();
