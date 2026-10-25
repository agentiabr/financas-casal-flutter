-- Lock down the legacy tables and attach pre-family records to the first family owner.
-- This migration preserves existing rows; it does not delete financial records.
begin;

-- The client-side snapshot contained the Gemini API key. Remove only that secret
-- while retaining the remainder of the row for a later authenticated migration.
update public.transactions
set descricao=(descricao::jsonb - 'geminiKey')::text
where id=999999 and jsonb_typeof(descricao::jsonb)='object' and descricao::jsonb ? 'geminiKey';

create table if not exists public.household_app_snapshots (
  household_id bigint not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key(household_id,user_id)
);
alter table public.household_app_snapshots enable row level security;
drop policy if exists "household app snapshot read" on public.household_app_snapshots;
drop policy if exists "household app snapshot insert" on public.household_app_snapshots;
drop policy if exists "household app snapshot update" on public.household_app_snapshots;
create policy "household app snapshot read" on public.household_app_snapshots for select to authenticated
  using (public.is_household_member(household_id) and (
    user_id=auth.uid()
    or exists(select 1 from public.households h where h.id=household_id and h.finance_mode='shared')
    or exists(select 1 from public.household_members owner where owner.household_id=household_id and owner.user_id=household_app_snapshots.user_id and owner.finance_visibility='shared')
  ));
create policy "household app snapshot insert" on public.household_app_snapshots for insert to authenticated
  with check (user_id=auth.uid() and public.is_household_member(household_id));
create policy "household app snapshot update" on public.household_app_snapshots for update to authenticated
  using (user_id=auth.uid() and public.is_household_member(household_id))
  with check (user_id=auth.uid() and public.is_household_member(household_id));
revoke all on public.household_app_snapshots from public,anon;
grant select,insert,update on public.household_app_snapshots to authenticated;
create unique index if not exists household_members_one_family_per_user_idx
  on public.household_members(user_id) where user_id is not null;
-- Add ownership to all existing finance tables. Legacy rows are claimed by the
-- first authenticated family admin through create_household_for_current_user.
do $$
declare t text;
begin
  foreach t in array array['credit_cards','piggies','cycles','installments','food_budget'] loop
    execute format('alter table public.%I add column if not exists household_id bigint references public.households(id) on delete cascade',t);
    execute format('alter table public.%I add column if not exists user_id uuid references auth.users(id) default auth.uid()',t);
  end loop;
end $$;
create index if not exists household_members_household_user_key on public.household_members(household_id,user_id);
create index if not exists credit_cards_household_id_idx on public.credit_cards(household_id);
create index if not exists credit_cards_user_id_idx on public.credit_cards(user_id);
create index if not exists piggies_household_id_idx on public.piggies(household_id);
create index if not exists piggies_user_id_idx on public.piggies(user_id);
create index if not exists cycles_household_id_idx on public.cycles(household_id);
create index if not exists cycles_user_id_idx on public.cycles(user_id);
create index if not exists installments_household_id_idx on public.installments(household_id);
create index if not exists installments_user_id_idx on public.installments(user_id);
create index if not exists food_budget_household_id_idx on public.food_budget(household_id);
create index if not exists food_budget_user_id_idx on public.food_budget(user_id);

-- Automatically attribute new rows to the signed-in member and prevent ordinary
-- clients from transferring rows between users or households.
create or replace function public.attach_authenticated_finance_owner()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then return new; end if;
  if tg_op='INSERT' then
    new.user_id:=auth.uid();
    if new.household_id is null then
      select hm.household_id into new.household_id from public.household_members hm where hm.user_id=auth.uid() limit 1;
    elsif not public.is_household_member(new.household_id) then
      raise exception 'Not a member of this household';
    end if;
  else
    if (new.user_id is distinct from old.user_id or new.household_id is distinct from old.household_id)
       and current_setting('app.claiming_legacy_finance',true) is distinct from 'true' then
      raise exception 'Finance ownership cannot be changed';
    end if;
  end if;
  return new;
end; $$;
revoke all on function public.attach_authenticated_finance_owner() from public,anon,authenticated;

do $$
declare t text;
begin
  foreach t in array array['transactions','credit_cards','piggies','cycles','installments','food_budget','price_history'] loop
    execute format('drop trigger if exists attach_finance_owner on public.%I',t);
    execute format('create trigger attach_finance_owner before insert or update on public.%I for each row execute function public.attach_authenticated_finance_owner()',t);
  end loop;
end $$;

-- Replace permissive policies on every legacy finance table. RLS policies are OR-combined,
-- so removing the old public policies is required for the new restrictions to work.
 drop policy if exists "Acesso Total Transactions" on public.transactions;
 drop policy if exists "Transactions Household Isolation" on public.transactions;
 drop policy if exists "family transactions access" on public.transactions;
 create policy "family transactions access" on public.transactions for all to authenticated
   using (user_id=auth.uid() or (household_id is not null and public.can_read_household_transaction(household_id,user_id)))
   with check (user_id=auth.uid() or (household_id is not null and public.can_read_household_transaction(household_id,user_id)));

 do $$
 declare t text; policy_name text;
 begin
   foreach t in array array['credit_cards','piggies','cycles','installments','food_budget'] loop
     policy_name:=case t when 'credit_cards' then 'Acesso Total CreditCards' when 'food_budget' then 'Acesso Total FoodBudget' else 'Acesso Total '||initcap(t) end;
     execute format('drop policy if exists %I on public.%I',policy_name,t);
     execute format('drop policy if exists %I on public.%I','family finance access',t);
     execute format('alter table public.%I enable row level security',t);
     execute format('create policy %I on public.%I for all to authenticated using (user_id=auth.uid() or (household_id is not null and public.can_read_household_transaction(household_id,user_id))) with check (user_id=auth.uid() or (household_id is not null and public.can_read_household_transaction(household_id,user_id)))','family finance access',t);
   end loop;
 end $$;

 drop policy if exists "Acesso Total PriceHistory" on public.price_history;
 drop policy if exists "PriceHistory Household Isolation" on public.price_history;
 drop policy if exists "family price history access" on public.price_history;
 create policy "family price history access" on public.price_history for all to authenticated
   using (user_id=auth.uid() or (household_id is not null and public.is_household_member(household_id)))
   with check (user_id=auth.uid() and (household_id is null or public.is_household_member(household_id)));

-- No anonymous role may read or mutate financial records. Authenticated access is
-- governed by the household/owner policies above.
revoke all on public.transactions,public.credit_cards,public.piggies,public.cycles,
  public.installments,public.food_budget,public.price_history from public,anon;
grant select,insert,update,delete on public.transactions,public.credit_cards,public.piggies,
  public.cycles,public.installments,public.food_budget,public.price_history to authenticated;
revoke all on public.households,public.household_members,public.household_invites from public,anon;
revoke all on public.family_conversations,public.family_chat_messages,public.shopping_lists,
  public.shopping_list_items,public.shopping_receipts,public.shopping_receipt_items from public,anon;

grant usage,select on all sequences in schema public to authenticated;
revoke all on all sequences in schema public from public,anon;

-- A new family owner becomes the custodian of the pre-family records, keeping those
-- records recoverable while future access is governed by the chosen family mode.
create or replace function public.create_household_for_current_user(p_name text,p_finance_mode text default 'shared')
returns bigint language plpgsql security definer set search_path=public,pg_temp as $$
declare v_household_id bigint; v_email text; v_name text:=left(trim(coalesce(p_name,'')),100); v_visibility text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if v_name='' then raise exception 'Household name is required'; end if;
  if exists(select 1 from public.household_members where user_id=auth.uid()) then raise exception 'User already belongs to a household'; end if;
  select email into v_email from auth.users where id=auth.uid();
  v_visibility:=case when p_finance_mode='separate' then 'private' else 'shared' end;
  insert into public.households(nome_familia,plano,max_membros,finance_mode)
    values(v_name,'familia',6,case when p_finance_mode='separate' then 'separate' else 'shared' end)
    returning id into v_household_id;
  insert into public.household_members(household_id,user_id,nome,email,papel,financial_profile,finance_visibility)
    values(v_household_id,auth.uid(),v_name,coalesce(v_email,''),'admin','adult',v_visibility);
  insert into public.household_app_snapshots(household_id,user_id,payload)
    select v_household_id,auth.uid(),(descricao::jsonb-'geminiKey'-'transactions')
    from public.transactions where id=999999 and jsonb_typeof(descricao::jsonb)='object'
    on conflict(household_id,user_id) do update set payload=excluded.payload,updated_at=now();  perform set_config('app.claiming_legacy_finance','true',true);
  update public.transactions set household_id=v_household_id,user_id=auth.uid()
    where id<>999999 and ciclo<>'__SYSTEM_BACKUP__' and tipo<>'__CLOUD_SNAPSHOT__' and household_id is null and user_id is null;
  update public.credit_cards set household_id=v_household_id,user_id=auth.uid() where household_id is null and user_id is null;
  update public.piggies set household_id=v_household_id,user_id=auth.uid() where household_id is null and user_id is null;
  update public.cycles set household_id=v_household_id,user_id=auth.uid() where household_id is null and user_id is null;
  update public.installments set household_id=v_household_id,user_id=auth.uid() where household_id is null and user_id is null;
  update public.food_budget set household_id=v_household_id,user_id=auth.uid() where household_id is null and user_id is null;
  update public.price_history set household_id=v_household_id,user_id=auth.uid() where household_id is null and user_id is null;
  return v_household_id;
end; $$;
revoke all on function public.create_household_for_current_user(text,text) from public,anon;
grant execute on function public.create_household_for_current_user(text,text) to authenticated;

commit;