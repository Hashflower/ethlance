pragma solidity ^0.5.0;

import "./EthlanceRegistry.sol";
import "./EthlanceUserFactory.sol";
import "./EthlanceUser.sol";
import "./EthlanceJobStore.sol";
import "./EthlanceDispute.sol";
import "./EthlanceInvoice.sol";
import "./EthlanceFeedback.sol";
import "./EthlanceComment.sol";
import "proxy/MutableForwarder.sol";
import "proxy/Forwarder.sol";       // target(EthlanceInvoice)
import "proxy/SecondForwarder.sol"; // target(EthlanceDispute)
import "proxy/ThirdForwarder.sol";  // target(EthlanceComment)
import "proxy/FourthForwarder.sol"; // target(EthlanceFeedback)


/// @title Work Contract to tie candidates, employers, and arbiters to
/// an agreement.
contract EthlanceWorkContract {
    uint public constant version = 1;
    EthlanceRegistry public constant registry = EthlanceRegistry(0xdaBBdABbDABbDabbDaBbDabbDaBbdaBbdaBbDAbB);

    //
    // Constants
    //
    uint public constant GUEST_TYPE = 0;
    uint public constant EMPLOYER_TYPE = 1;
    uint public constant CANDIDATE_TYPE = 2;
    uint public constant ARBITER_TYPE = 3;

    //
    // Structures
    //

    // Nothing here yet.

    //
    // Members
    //

    // The status of contract with respect to the employer and the
    // candidate's interactions.
    //
    // Notes:
    //
    // - The overall status of the contract will also be reflected
    //   with respect to any open disputes.
    //
    // Status Codes:
    // -----------
    // 0  -> Initial
    // --
    // 1  -> Request Candidate Invite
    // 2  -> Request Employer Invite
    // 3  -> Open Bounty
    // --
    // 4  -> Accepted
    // --
    // 5  -> In Progress
    // 6  -> On Hold
    // --
    // 7  -> Request Candidate Finished
    // 8  -> Request Employer Finished
    // 9  -> Finished
    // --
    // 10 -> Cancelled
    uint public contract_status;
    uint public constant CONTRACT_STATUS_INITIAL = 0;
    uint public constant CONTRACT_STATUS_REQUEST_CANDIDATE_INVITE = 1;
    uint public constant CONTRACT_STATUS_REQUEST_EMPLOYER_INVITE = 2;
    uint public constant CONTRACT_STATUS_OPEN_BOUNTY = 3;
    uint public constant CONTRACT_STATUS_ACCEPTED = 4;
    uint public constant CONTRACT_STATUS_IN_PROGRESS = 5;
    uint public constant CONTRACT_STATUS_ON_HOLD = 6;
    uint public constant CONTRACT_STATUS_REQUEST_CANDIDATE_FINISHED = 7;
    uint public constant CONTRACT_STATUS_REQUEST_EMPLOYER_FINISHED = 8;
    uint public constant CONTRACT_STATUS_FINISHED = 9;
    uint public constant CONTRACT_STATUS_CANCELLED = 10;
    
    uint public job_index;
    uint public work_index;

    // The EthlanceJobStore contains additional data about our
    // contract.
    EthlanceJobStore public store_instance;

    // The candidate linked to this contract
    address payable public candidate_address;

    uint public date_created;
    uint public date_updated;

    // Feedback Store
    

    //
    // Collections
    //
    
    // Dispute Listing
    EthlanceDispute[] public dispute_listing;

    // Invoice Listing
    EthlanceInvoice[] public invoice_listing;


    /// @dev Forwarder Constructor
    function construct(EthlanceJobStore _store_instance,
		       uint _work_index,
		       address payable _candidate_address,
		       bool is_employer_request)
	public {
	// require(registry.checkFactoryPrivilege(msg.sender), "You are not privileged to carry out construction.");

	// Main members
	store_instance = _store_instance;
	work_index = _work_index;
	candidate_address = _candidate_address;
	date_created = now;
	date_updated = now;
	
	// Event Data Construction
	job_index = store_instance.job_index();


	if (is_employer_request) {
	    requestInvite(store_instance.employer_address());
	    return;
	}
	requestInvite(candidate_address);
	return;
    }

    //
    // Methods
    //

    /// @dev Update the datetime of the job contract.
    function updateDateUpdated()
	private {
	date_updated = now;
    }

    
    /// @dev Change the contract status
    /// @param new_status The new contract status
    function setContractStatus(uint new_status) private {
	contract_status = new_status;
	updateDateUpdated();
    }


    /// @dev Requests an invite from either the candidate or the employer.
    /// @param _sender Delegation for initial work contract construction.
    /*
      Case 1:
      
      requestInvite() is initially called while the contract is in a
      CONTRACT_STATUS_INITIAL state and the store_instance.is_bounty
      is true. The Contract is placed in a CONTRACT_STATUS_OPEN_BOUNTY
      state.

      Case 2:
      
      requestInvite() is initially called while the contract is in a
      CONTRACT_STATUS_INITIAL state and the contract is placed in a
      CONTRACT_STATUS_EMPLOYER_INVITE state.

      Case 3:

      requestInvite() is initially called while the contract is in a
      CONTRACT_STATUS_INITIAL state and the contract is placed in a
      CONTRACT_STATUS_CANDIDATE_INVITE state.

      Case 4:

      requestInvite() is called while the contract is in a
      CONTRACT_STATUS_CANDIDATE_INVITE state and the contract is
      placed in a CONTRACT_STATUS_ACCEPTED state.

      Case 5:

      requestInvite() is called while the contract is in a
      CONTRACT_STATUS_EMPLOYER_INVITE state and the contract is placed
      in a CONTRACT_STATUS_ACCEPTED state.
      
      Default:

      ERROR
     */
    function requestInvite(address _sender)
	public {
	
	if (address(store_instance) == msg.sender) {/* _sender has been loaded by the constructor */}
	else if (store_instance.employer_address() == msg.sender || candidate_address == msg.sender) {
	    _sender = msg.sender;
	}
	else {
	    revert("Only the job store, candidate and employer can request an invite.");
	}

	bool is_employer_request = false;
	if (store_instance.employer_address() == _sender) {
	    is_employer_request = true;
	}

	// Case 1
	if (store_instance.bid_option() == store_instance.BID_OPTION_BOUNTY()) {
	    setContractStatus(CONTRACT_STATUS_OPEN_BOUNTY);
	    fireEvent("JobRequestWorkContract");
	    return;
	}

	// Case 2 & 3
	if (contract_status == CONTRACT_STATUS_INITIAL) {
	    if (is_employer_request) {
		setContractStatus(CONTRACT_STATUS_REQUEST_EMPLOYER_INVITE);
		fireEvent("JobRequestWorkContract");
		return;
	    }
	    setContractStatus(CONTRACT_STATUS_REQUEST_CANDIDATE_INVITE);
	    fireEvent("JobRequestWorkContract");
	    return;
	}
	
	// Case 4
	if (is_employer_request && contract_status == CONTRACT_STATUS_REQUEST_CANDIDATE_INVITE) {
	    setContractStatus(CONTRACT_STATUS_ACCEPTED);
	    fireEvent("JobAcceptWorkContract");
	    return;
	}

	// Case 5
	if (!is_employer_request && contract_status == CONTRACT_STATUS_REQUEST_EMPLOYER_INVITE) {
	    setContractStatus(CONTRACT_STATUS_ACCEPTED);
	    fireEvent("JobAcceptWorkContract");
	    return;
	}

	revert("Failed to meet required requestInvite criteria");
    }

    
    /// @dev Overloaded requestInvite for direct employer and candidate requests.
    /*
      Notes:

      - The address is set to 0x0 to reflect that it's a direct
        request from a candidate, or an employer.

     */
    function requestInvite() public {
	requestInvite(address(0));
    }
    

    /// @dev Start the work contract
    /*
      Notes:

      - This requires that the contract be within the CONTRACT_STATUS_ACCEPTED state.
     */
    function proceed() external {
	require(store_instance.employer_address() == msg.sender,
		"Must be an employer to start a contract");
	require(store_instance.accepted_arbiter() != address(0),
		"Must be an accepted arbiter before work contracts can proceed");

	if (contract_status == CONTRACT_STATUS_ACCEPTED) {
	    setContractStatus(CONTRACT_STATUS_IN_PROGRESS);
	    fireEvent("JobProceedWorkContract");
	}
	else {
	    revert("Cannot start a contract if it is not in the 'accepted' state.");
	}
    }


    /// @dev Request to finish the contract as the employer or the candidate
    /*
      Case 1:

      While in the CONTRACT_STATUS_IN_PROGRESS state, and if the
      candidate invokes requestFinished(), the contract will be placed
      in the CONTRACT_STATUS_REQUEST_CANDIDATE_FINISHED state.

      Case 2:

      While in the CONTRACT_STATUS_IN_PROGRESS state, and if the
      employer invokes requestFinished(), the contract will be placed
      in the CONTRACT_STATUS_REQUEST_EMPLOYER_FINISHED state.
      
      Case 3:

      While in the CONTRACT_STATUS_REQUEST_EMPLOYER_FINISHED state,
      and if the candidate invokes requestFinished(), the contract
      will be placed in the CONTRACT_STATUS_FINISHED state.

      Case 4:

      While in the CONTRACT_STATUS_REQUEST_CANDIDATE_FINISHED state,
      and if the employer invokes requestFinished(), the contract will
      be placed in the CONTRACT_STATUS_FINISHED state.

     */
    function requestFinished() external {
	require(store_instance.employer_address() == msg.sender || candidate_address == msg.sender,
		"Only the candidate and the employer can request finishing the contract.");

	bool is_employer_request = false;
	if (store_instance.employer_address() == msg.sender) {
	    is_employer_request = true;
	}

	// Case 1 & 2
	if (contract_status == CONTRACT_STATUS_IN_PROGRESS) {
	    if (is_employer_request) {
		setContractStatus(CONTRACT_STATUS_REQUEST_EMPLOYER_FINISHED);
		fireEvent("WorkContractRequestFinished");
		return;
	    }
	    setContractStatus(CONTRACT_STATUS_REQUEST_CANDIDATE_FINISHED);
	    fireEvent("WorkContractRequestFinished");
	    return;
	}
	
	// Case 3
	if (!is_employer_request && contract_status == CONTRACT_STATUS_REQUEST_EMPLOYER_FINISHED) {
	    setContractStatus(CONTRACT_STATUS_FINISHED);
	    fireEvent("WorkContractFinished");
	    return;
	}

	// Case 4
	if (is_employer_request && contract_status == CONTRACT_STATUS_REQUEST_CANDIDATE_FINISHED) {
	    setContractStatus(CONTRACT_STATUS_FINISHED);
	    fireEvent("WorkContractFinished");
	    return;
	}

	revert("Failed to meet requestFinished criteria.");
    }
    

    /// @dev Fire events specific to the work contract
    /// @param event_name Unique to give the fired event
    function fireEvent(string memory event_name) private {
	// Event Data Pre-construction
	uint[] memory event_data = new uint[](2);
	event_data[0] = job_index;
	event_data[1] = work_index;

	registry.fireEvent(event_name, version, event_data);
    }


    /// @dev Create a dispute between the employer and the candidate.
    /// @param reason Short string with the reason for the dispute.
    /// @param metahash Represents a IPFS hash with a longer
    /// explanation for the dispute by either the employer or the
    /// candidate.
    function createDispute(string memory reason, string memory metahash) public {
	// TODO: authentication
	require(candidate_address == msg.sender || store_instance.employer_address() == msg.sender,
		"Only the employer and the candidate can create new disputes.");
	require(contract_status == CONTRACT_STATUS_IN_PROGRESS ||
		contract_status == CONTRACT_STATUS_ON_HOLD ||
		contract_status == CONTRACT_STATUS_REQUEST_EMPLOYER_FINISHED ||
		contract_status == CONTRACT_STATUS_REQUEST_CANDIDATE_FINISHED,
		"The current contract status does not allow you to create a dispute.");

	bool is_employer_request = false;
	if (store_instance.employer_address() == msg.sender) {
	    is_employer_request = true;
	}

	// Create the forwarded contract
	SecondForwarder fwd = new SecondForwarder(); // Proxy Contract
                                                     // target(EthlanceDispute)

	// Permit Dispute to fire registry events and create comments
	registry.permitDispatch(address(fwd));

	EthlanceDispute dispute = EthlanceDispute(address(fwd));
	uint dispute_index = dispute_listing.length;
	dispute_listing.push(dispute);
	
	// Construct the dispute contract
	dispute.construct(this, dispute_index, reason, metahash, is_employer_request);

	// Change our status to 'on hold', since we have a new open dispute.
	setContractStatus(CONTRACT_STATUS_ON_HOLD);
    }

    
    /// @dev Returns the number of disputes within the work contract
    function getDisputeCount() public view returns(uint) {
	return dispute_listing.length;
    }

    
    /// @dev Returns the address of the EthlanceDispute at the given
    /// index within the dispute listing.
    function getDisputeByIndex(uint index) public view returns (EthlanceDispute) {
	return dispute_listing[index];
    }


    /// @dev Resolves a dispute.
    /*
      Notes:

      - The original EthlanceDispute.resolve(...) propagates to this method.

      - This function only ensures that it is a call from an
        EthlanceDispute. The result is propagated to the job store for
        resolution.
     */
    function resolveDispute(uint _employer_amount,
			    address _employer_token,
			    uint _candidate_amount,
			    address _candidate_token,
			    uint _arbiter_amount,
			    address _arbiter_token) external {
	require(isDispute(msg.sender), "Only a dispute contract can 'resolve' a dispute.");
	store_instance.resolveDispute(_employer_amount, _employer_token,
				      _candidate_amount, _candidate_token,
				      _arbiter_amount, _arbiter_token,
				      candidate_address);
    }

    
    /// @dev Determines whether the given address is an
    /// EthlanceDispute contract that is part of the current
    /// EthlanceWorkContract.
    /// @return True, if it is an EthlanceDispute contract that is
    /// part of the EthlanceWorkContract.
    function isDispute(address _dispute) private returns(bool) {
	for (uint i = 0; i < dispute_listing.length; i++) {
	    if (address(dispute_listing[i]) == _dispute) {
		return true;
	    }
	}
	return false;
    }


    /// @dev Create an invoice between the employer and the candidate.
    /// @param metahash Contains additional information about the invoice
    function createInvoice(uint amount, string memory metahash) public {
	// Create the forwarded contract
	Forwarder fwd = new Forwarder(); // Proxy Contract
	                                 // target(EthlanceInvoice)
	EthlanceInvoice invoice = EthlanceInvoice(address(fwd));

	// Permit Invoice to fire registry events
	registry.permitDispatch(address(fwd));

	uint invoice_index = invoice_listing.length;
	invoice_listing.push(invoice);
	
	// Construct the invoice contract
	invoice.construct(this, invoice_index, amount, metahash);
    }

    
    /// @dev Pays an invoice
    /*
      Notes:

      - The original EthlanceInvoice.pay(...) propagates to this method.

      - This function only ensures that it is receiving a payment
        request from the desired invoice. The result is propagated to
        the job store for payment.
     */
    function payInvoice(uint amount_paid) external {
	require(isInvoice(msg.sender), "Only an invoice contract can 'pay' an invoice.");
	store_instance.payInvoice(candidate_address, amount_paid);
    }


    /// @dev Determines whether the given address is an
    /// EthlanceInvoice contract that is part of the current
    /// EthlanceWorkContract.
    /// @return True, if it is an EthlanceInvoice contract that is
    /// part of the EthlanceWorkContract.
    function isInvoice(address _invoice) private returns(bool) {
	for (uint i = 0; i < invoice_listing.length; i++) {
	    if (address(invoice_listing[i]) == _invoice) {
		return true;
	    }
	}
	return false;
    }

    
    /// @dev Returns the number of invoices within the work contract
    function getInvoiceCount() public view returns(uint) {
	return invoice_listing.length;
    }

    
    /// @dev Returns the address of the EthlanceInvoice at the given
    /// index within the invoice listing.
    function getInvoiceByIndex(uint index) public view returns (EthlanceInvoice) {
	return invoice_listing[index];
    }


    /// @dev Returns the user type, either CANDIDATE_TYPE,
    /// EMPLOYER_TYPE, ARBITER_TYPE, or GUEST_TYPE for the given
    /// address.
    function getUserType(address _address) private returns (uint) {
	if (_address == candidate_address) {
	    return CANDIDATE_TYPE;
	}
	else if (_address == store_instance.employer_address()) {
	    return EMPLOYER_TYPE;
	}
	else if (_address == store_instance.accepted_arbiter()) {
	    return ARBITER_TYPE;
	}
	else {
	    return GUEST_TYPE;
	}
    }


    /// @dev Place a comment on the dispute
    function addComment(string calldata metahash) external {
	uint user_type = getUserType(msg.sender);
	require(user_type != GUEST_TYPE,
		"Only the candidate, employer, and arbiter can comment.");
	
	// Create the forwarded contract
        ThirdForwarder fwd = new ThirdForwarder(); // Proxy Contract
                                                   // target(EthlanceComment)
        EthlanceComment comment = EthlanceComment(address(fwd));

	// Permit Comment to fire registry events
	registry.permitDispatch(address(fwd));

	// Add comment to the registry comment listing
	registry.pushComment(address(this), address(comment));

	uint[4] memory index;
	index[0] = store_instance.job_index();
	index[1] = work_index;
	index[2] = registry.getCommentCount(address(this)) - 1;

	// Construct the comment contract
	comment.construct(msg.sender,
			  user_type,
			  metahash,
			  EthlanceComment.CommentType.WorkContract,
			  index);
    }

    
    /// @dev Leave feedback on the given work contract
    /*
      Notes:

      - Only the candidate and the employer can leave feedback on a work contract.
        - A candidate leaving feedback is meant for the employer.
	- An employer leaving feedback is meant for the candidate.
     */
    function leaveFeedback(uint rating, string calldata metahash) external {
	uint user_type = getUserType(msg.sender);
	require(user_type == CANDIDATE_TYPE || user_type == EMPLOYER_TYPE,
		"Only the candidate or the employer, can leave feedback.");
	
	uint to_user_type;
	address to_user_address;
	
	if (user_type == CANDIDATE_TYPE) {
	    to_user_type = EMPLOYER_TYPE;
	    to_user_address = store_instance.employer_address();
	}
	else {
	    to_user_type = CANDIDATE_TYPE;
	    to_user_address = candidate_address;
	}
	
	// Check and create forwarded feedback contract instance
	EthlanceFeedback feedback;
	if (!registry.hasFeedback(address(this))) {
	    FourthForwarder fwd = new FourthForwarder(); // Proxy Contract
	                                                 // target(EthlanceFeedback)

	    feedback = EthlanceFeedback(address(fwd));

	    // Permit Feedback to fire registry events
	    registry.permitDispatch(address(fwd));
	    
	    // Add feedback to the registry feedback mapping
	    registry.pushFeedback(address(this), address(fwd));
	    
	    // Construct the feedback contract
	    feedback.construct(address(this), job_index, work_index);
	}
	else {
	    feedback = EthlanceFeedback(registry.getFeedbackByAddress(address(this)));
	}

	feedback.update(msg.sender,
			to_user_address,
			user_type,
			to_user_type,
			metahash,
			rating);
    }
}
