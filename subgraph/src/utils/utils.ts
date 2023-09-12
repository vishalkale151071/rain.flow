import { ethereum } from "@graphprotocol/graph-ts";
import { Transaction } from "../../generated/schema";

export function createTransaction(transation: ethereum.Transaction, block: ethereum.Block): Transaction {
    let transation_ = Transaction.load(transation.hash.toHexString());
    if (transation_ == null) {
        transation_ = new Transaction(transation.hash.toHexString());
        transation_.blockNumber = block.number;
        transation_.timestamp = block.timestamp;
        transation_.from = transation.from;
        transation_.save();
    }
    return transation_;
}