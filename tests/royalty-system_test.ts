import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test artist registration with tiers",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('royalty-system', 'register-artist', [
                types.ascii("Test Artist"),
                types.uint(10),
                types.uint(2)
            ], deployer.address),
            
            // Non-owner should fail
            Tx.contractCall('royalty-system', 'register-artist', [
                types.ascii("Failed Artist"),
                types.uint(10),
                types.uint(1)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr(types.uint(100));
    },
});

Clarinet.test({
    name: "Test concert creation with ticket sales",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('royalty-system', 'create-concert', [
                types.uint(1),
                types.ascii("Test Concert"),
                types.uint(1234567890),
                types.uint(100),
                types.uint(1000)
            ], deployer.address),
            
            Tx.contractCall('royalty-system', 'purchase-tickets', [
                types.uint(1),
                types.uint(2)
            ], wallet1.address)
        ]);
        
        block.receipts.map(receipt => {
            receipt.result.expectOk();
        });
        
        // Verify concert and ticket info
        let infoBlock = chain.mineBlock([
            Tx.contractCall('royalty-system', 'get-concert-info', [
                types.uint(1)
            ], deployer.address),
            
            Tx.contractCall('royalty-system', 'get-ticket-info', [
                types.uint(1),
                wallet1.address
            ], wallet1.address)
        ]);
        
        const concertInfo = infoBlock.receipts[0].result.expectSome();
        const ticketInfo = infoBlock.receipts[1].result.expectSome();
        assertEquals(concertInfo['tickets-sold'], types.uint(2));
        assertEquals(ticketInfo['quantity'], types.uint(2));
    },
});

Clarinet.test({
    name: "Test ticket claiming",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Setup concert and purchase tickets
        let setup = chain.mineBlock([
            Tx.contractCall('royalty-system', 'create-concert', [
                types.uint(1),
                types.ascii("Test Concert"),
                types.uint(1234567890),
                types.uint(100),
                types.uint(1000)
            ], deployer.address),
            
            Tx.contractCall('royalty-system', 'purchase-tickets', [
                types.uint(1),
                types.uint(2)
            ], wallet1.address)
        ]);
        
        // Test claiming
        let claim = chain.mineBlock([
            Tx.contractCall('royalty-system', 'claim-ticket', [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        claim.receipts[0].result.expectOk();
        
        // Verify claimed status
        let verifyBlock = chain.mineBlock([
            Tx.contractCall('royalty-system', 'get-ticket-info', [
                types.uint(1),
                wallet1.address
            ], wallet1.address)
        ]);
        
        const ticketInfo = verifyBlock.receipts[0].result.expectSome();
        assertEquals(ticketInfo['claimed'], true);
    },
});
