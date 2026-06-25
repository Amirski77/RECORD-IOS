import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://xmkrrrvvtxydxgknelha.supabase.co")!,
    supabaseKey: "sb_publishable_2MMXstdbLHJLNKKCQGQemA_eXO1twRD",
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            emitLocalSessionAsInitialSession: true
        )
    )
)
