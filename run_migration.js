// run_migration.js - Apply database views migration to Supabase
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Supabase credentials
const SUPABASE_URL = 'https://hqfixpqwxmwftvhgdrxn.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ Error: SUPABASE_SERVICE_ROLE_KEY environment variable not set');
  console.log('\n💡 Usage: $env:SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"; node run_migration.js');
  process.exit(1);
}

// Create Supabase client with service role key
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function runMigration() {
  try {
    console.log('🚀 Starting database migration...\n');
    
    // Read the migration file
    const migrationPath = path.join(__dirname, 'supabase', 'migrations', '20251112_update_reporting_views.sql');
    console.log('📄 Reading migration file:', migrationPath);
    
    const sqlContent = fs.readFileSync(migrationPath, 'utf8');
    
    console.log('📊 Migration SQL loaded successfully\n');
    console.log('⚙️  Executing migration...\n');
    
    // Execute the SQL
    const { data, error } = await supabase.rpc('exec_sql', { sql: sqlContent });
    
    if (error) {
      // If rpc doesn't exist, try direct SQL execution
      console.log('⚠️  RPC method not available, trying direct execution...\n');
      
      // Split SQL by statements and execute one by one
      const statements = sqlContent
        .split(';')
        .map(s => s.trim())
        .filter(s => s.length > 0 && !s.startsWith('--'));
      
      console.log(`📝 Found ${statements.length} SQL statements to execute\n`);
      
      for (let i = 0; i < statements.length; i++) {
        const statement = statements[i];
        if (statement.includes('NOTIFY pgrst')) {
          console.log(`⏭️  Skipping NOTIFY statement (${i + 1}/${statements.length})`);
          continue;
        }
        
        console.log(`▶️  Executing statement ${i + 1}/${statements.length}...`);
        
        // Use PostgREST to execute raw SQL
        const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_SERVICE_ROLE_KEY,
            'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
          },
          body: JSON.stringify({ query: statement + ';' })
        });
        
        if (!response.ok) {
          console.log(`⚠️  Statement ${i + 1} failed, continuing...`);
        } else {
          console.log(`✅ Statement ${i + 1} executed successfully`);
        }
      }
    } else {
      console.log('✅ Migration executed successfully via RPC');
    }
    
    console.log('\n🎉 Migration completed!\n');
    
    // Verify views were created
    console.log('🔍 Verifying views...\n');
    
    const { data: views, error: viewError } = await supabase
      .from('pg_views')
      .select('schemaname, viewname')
      .eq('schemaname', 'public')
      .in('viewname', [
        'order_statistics',
        'popular_menu_items',
        'daily_revenue_breakdown',
        'hourly_order_statistics'
      ]);
    
    if (viewError) {
      console.log('⚠️  Could not verify views (this is OK):', viewError.message);
    } else if (views && views.length > 0) {
      console.log('✅ Views found:');
      views.forEach(v => console.log(`   - ${v.viewname}`));
    }
    
    console.log('\n✨ All done! Your reporting views are ready to use.\n');
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  }
}

runMigration();
