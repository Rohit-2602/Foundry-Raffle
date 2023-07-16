-include .env

help:
	@echo "Usage:"
	@echo "make install                           ---> Installs required contracts and dependencies"
	@echo "make install-brownie-contract          ---> Installs smartcontractkit/chainlink-brownie-contracts"
	@echo "make install-openzeppelin-contract     ---> Installs OpenZeppelin/openzeppelin-contracts"
	@echo "make commit-push                       ---> Commits and pushes changes to Git repository"

# Install the smartcontractkit/chainlink-brownie-contracts package
install-brownie-contract:; forge install smartcontractkit/chainlink-brownie-contracts --no-commit

# Install the OpenZeppelin/openzeppelin-contracts package
install-openzeppelin-contract:; forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Install required contracts and dependencies
install:; forge install OpenZeppelin/openzeppelin-contracts --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit

# Commit and push changes to the Git repository
commit-push:
	@read -p "Enter a commit message: " message; \
	git add . && git commit -m "$$message" && git push
