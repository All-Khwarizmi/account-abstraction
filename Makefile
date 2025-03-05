
.PHONY: install

install:
	forge install eth-infinitism/account-abstraction --no-commit
	forge install foundry-rs/forge-std --no-commit
	forge install openzeppelin/openzeppelin-contracts --no-commit