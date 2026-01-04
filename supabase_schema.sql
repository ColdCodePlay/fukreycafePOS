
-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- PROFILES (Users with roles)
create table profiles (
  id uuid references auth.users not null primary key,
  email text,
  role text check (role in ('admin', 'staff')) default 'staff',
  outlet_id uuid references outlets(id),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Function to handle new user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, new.email, 'staff'); -- Default to staff, admin can manually upgrade
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to call the function
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- OUTLETS
create table outlets (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  address text,
  phone text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- CATEGORIES
create table categories (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  outlet_id uuid references outlets(id), -- Null means global category
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- MENU ITEMS
create table menu_items (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  description text,
  price numeric not null,
  category_id uuid references categories(id),
  outlet_id uuid references outlets(id), -- Null means global item
  image_url text,
  is_available boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- COUPONS
create table coupons (
  id uuid default uuid_generate_v4() primary key,
  code text unique not null,
  discount_type text check (discount_type in ('percentage', 'flat')) not null,
  value numeric not null,
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ORDERS
create table orders (
  id uuid default uuid_generate_v4() primary key,
  outlet_id uuid references outlets(id) not null,
  total_amount numeric not null,
  status text check (status in ('pending', 'completed', 'cancelled')) default 'pending',
  payment_method text,
  coupon_code text,
  discount_amount numeric default 0,
  tax_amount numeric default 0,
  customer_name text,
  customer_phone text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ORDER ITEMS
create table order_items (
  id uuid default uuid_generate_v4() primary key,
  order_id uuid references orders(id) not null,
  menu_item_id uuid references menu_items(id) not null,
  quantity integer not null,
  price numeric not null, -- snapshot of price at time of order
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- POLICIES (RLS)
-- You should enable RLS and add policies. For now, we assume public/authenticated access for simplicity or 'service_role' usage in some cases, 
-- but ideally:
-- Admins can do everything.
-- Staff can read menu, create orders.

alter table profiles enable row level security;
alter table outlets enable row level security;
alter table categories enable row level security;
alter table menu_items enable row level security;
alter table coupons enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;

-- Example generic policy (adjust as needed for security)
create policy "Enable all access for authenticated users" on profiles for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on outlets for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on categories for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on menu_items for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on coupons for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on orders for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on order_items for all using (auth.role() = 'authenticated');
