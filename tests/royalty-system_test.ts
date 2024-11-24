import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test artist registration",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('royalty-system', 'register-artist', [
                types.ascii("Test Artist"),
                types.uint(10)
            ], deployer.address),
            
            // Non-owner should fail
            Tx.contractCall('royalty-system', 'register-artist', [
                types.ascii("Failed Artist"),
                types.uint(10)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr(types.uint(100));
    },
});

Clarinet.test({
    name: "Test concert creation and revenue recording",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('royalty-system', 'create-concert', [
                types.uint(1),
                types.ascii("Test Concert"),
                types.uint(1234567890)
            ], deployer.address),
            
            Tx.contractCall('royalty-system', 'record-revenue', [
                types.uint(1),
                types.uint(1000)
            ], deployer.address)
        ]);
        
        block.receipts.map(receipt => {
            receipt.result.expectOk();
        });
        
        // Verify concert info
        let getInfoBlock = chain.mineBlock([
            Tx.contractCall('royalty-system', 'get-concert-info', [
                types.uint(1)
            ], deployer.address)
        ]);
        
        const concertInfo = getInfoBlock.receipts[0].result.expectSome();
        assertEquals(concertInfo['total-revenue'], types.uint(1000));
    },
});
