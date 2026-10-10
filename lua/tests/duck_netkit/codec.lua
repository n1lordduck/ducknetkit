return {
    groupName = "DuckNetKit.Codec",

    cases = {
        {
            name = "Encode/Decode round trips a small table without compression",
            func = function()
                local payload = { a = 1 }
                local bytes, flags = DuckNetKit.Encode( payload )
                local back = DuckNetKit.Decode( bytes, flags )

                expect( back.a ).to.equal( 1 )
                expect( bit.band( flags, DuckNetKit.FLAG_COMPRESSED ) ).to.equal( 0 )
            end
        },

        {
            name = "Encode compresses a large repetitive string and Decode restores it exactly",
            func = function()
                local big = string.rep( "duck_netkit_test_payload_", 2000 )
                local bytes, flags = DuckNetKit.Encode( big )
                local back = DuckNetKit.Decode( bytes, flags )

                expect( back ).to.equal( big )
                expect( bit.band( flags, DuckNetKit.FLAG_COMPRESSED ) ).toNot.equal( 0 )
                expect( #bytes ).to.beLessThan( #big )
            end
        },

        {
            name = "opts.compress = false skips compression even when it would help",
            func = function()
                local big = string.rep( "x", 5000 )
                local bytes, flags = DuckNetKit.Encode( big, { compress = false } )

                expect( bytes ).to.equal( big )
                expect( bit.band( flags, DuckNetKit.FLAG_COMPRESSED ) ).to.equal( 0 )
            end
        },

        {
            name = "A tiny payload where compression would not help falls back to the raw path",
            func = function()
                local payload = { a = 1 }
                local bytes, flags = DuckNetKit.Encode( payload )

                expect( bytes ).to.equal( util.TableToJSON( payload ) )
                expect( bit.band( flags, DuckNetKit.FLAG_TABLE ) ).toNot.equal( 0 )
            end
        },
    }
}
