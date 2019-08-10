pragma solidity >=0.4.21 <0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Earnings.sol";
import "./TeamRewards.sol";
import "./Terminator.sol";
import "./Recommend.sol";

import "./ResonanceF.sol";

contract Resonance is ResonanceF {
    using SafeMath for uint256;

    uint256     public totalSupply = 0;
    uint256     constant internal bonusPrice = 0.0000001 ether; 
    uint256     constant internal priceIncremental = 0.0000000001 ether; 
    uint256     constant internal magnitude = 2 ** 64;
    uint256     internal perBonusDivide = 0; 
    uint256     public  systemRetain = 0;
    uint256     public terminatorPoolAmount; 

    mapping(address => User) public userInfo; 
    mapping(address => address[]) public straightInviteAddress; 
    mapping(address => int256) internal payoutsTo;
    mapping(address => uint256[11]) public userSubordinateCount;
    mapping(address => uint256) public whitelistPerformance;
    mapping(address => UserReinvest) public userReinvest;

    uint256   constant internal investAgain = 3 ether;  
    uint8   constant internal remain = 20;      
    uint32  constant internal ratio = 1000;     
    uint32  constant internal blockNumber = 40000; 
    uint256 public   currentBlockNumber;
    uint256 public   straightSortRewards = 0;
    uint256  public initAddressAmount = 0;   
    uint256 public totalEthAmount = 0; 
    uint8 constant public percent = 100;

    address  public eggAddress = address(0xf49a77e2c0db7Df557540d22defAcBa99724E983);
    address  public systemAddress = address(0xa2178AC7153bB8ae0c1F0bE17aEe07945e6a8849);
    address [10] public straightSort; 

    Earnings internal earningsInstance;
    TeamRewards internal teamRewardInstance;
    Terminator internal terminatorInstance;
    Recommend internal recommendInstance;

    struct User {
        address userAddress;  
        uint256 ethAmount;    
        uint256 profitAmount; 
        uint256 tokenAmount;  
        uint256 tokenProfit;  
        uint256 straightEth;  
        uint256 lockStraight;
        uint256 teamEth;      
        bool staticTimeout;      
        uint256 staticTime;     
        uint8 level;        
        address straightAddress;
        uint256 refeTopAmount; 
        address refeTopAddress; 
    }

    struct UserReinvest {
        uint256 nodeReinvest;
        uint256 staticReinvest;
    }

    uint8[7] internal rewardRatio;

    uint8[11] internal teamRatio;

    modifier mustAdmin (address adminAddress){
        require(adminAddress != address(0));
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier mustReferralAddress (address referralAddress) {
        require(msg.sender != admin[0] || msg.sender != admin[1] || msg.sender != admin[2] || msg.sender != admin[3] || msg.sender != admin[4]);
        if (teamRewardInstance.isWhitelistAddress(msg.sender)) {
            require(referralAddress == admin[0] || referralAddress == admin[1] || referralAddress == admin[2] || referralAddress == admin[3] || referralAddress == admin[4]);
        }
        _;
    }

    modifier limitInvestmentCondition(uint256 ethAmount){
        if (initAddressAmount <= 100) {
            require(ethAmount <= 1 ether);
            _;
        } else if (initAddressAmount <= 500) {
            require(ethAmount <= 5 ether);
            _;
        } else {
            _;
        }
    }

    modifier limitAddressReinvest() {
        if (initAddressAmount <= 500 && userInfo[msg.sender].ethAmount > 0) {
            require(msg.value <= userInfo[msg.sender].ethAmount.mul(3));
        }
        _;
    }

    event GetReward(address indexed user, uint256 ethAmount);
    event JoinInvest(address indexed user, uint256 ethAmount, uint256 buyTime);
    event GoOut(address indexed user, uint256 ethAmount, uint8 indexed value, uint256 buyTime);
    event JoinAgain(address indexed user, uint256 indexed ethAmount, uint8 indexed value, uint256 buyTime);
    event HelpDown(uint256 indexed index, address indexed subordinate, address indexed refeAddress, bool supported);
    event Debug(uint256 indexed a, uint256 indexed b, uint256 indexed c, uint256 d);
    event LevelDebug(uint256 indexed levelUpCount, uint256  indexed currentInviteCount, uint8 indexed level);

    constructor(
        address _erc20Address,
        address _earningsAddress,
        address _teamRewardsAddress,
        address _terminatorAddress,
        address _recommendAddress
    )
    public
    {
        earningsInstance = Earnings(_earningsAddress);
        teamRewardInstance = TeamRewards(_teamRewardsAddress);
        terminatorInstance = Terminator(_terminatorAddress);
        kocInstance = KOCToken(_erc20Address);
        recommendInstance = Recommend(_recommendAddress);
        rewardRatio = [10, 30, 30, 29, 5, 5, 1];
        teamRatio = [6, 5, 4, 3, 3, 2, 2, 1, 1, 1, 1];
        currentBlockNumber = block.number;
    }

    function joinInvest(address upAddr,uint8 joinType,bool isWhite)
    public
    mustReferralAddress(upAddr)
    limitInvestmentCondition(msg.value) 
    payable
    {

        require(!teamRewardInstance.getWhitelistTime());
        uint256 ethAmount = msg.value;
        address userAddress = msg.sender;
        User storage _user = userInfo[userAddress];

        _user.userAddress = userAddress;

        if (_user.ethAmount == 0 && !teamRewardInstance.isWhitelistAddress(userAddress)) {
            teamRewardInstance.referralPeople(userAddress, upAddr);
            _user.straightAddress = upAddr;
        } else {
            require(upAddr == teamRewardInstance.getUserreferralAddress(userAddress));
        }

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        bool whitelist;
        (straightAddress, whiteAddress, adminAddress, whitelist) = teamRewardInstance.getUserSystemInfo(userAddress);
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);

        if (userInfo[upAddr].userAddress == address(0)) {
            userInfo[upAddr].userAddress = upAddr;
        }

        if (userInfo[userAddress].straightAddress == address(0)) {
            userInfo[userAddress].straightAddress = straightAddress;
        }

        uint256 _lockEth;
        uint256 _withdrawTeam;
        (, _lockEth, _withdrawTeam) = earningsInstance.getStaticAfterFoundsTeam(userAddress);

        if (ethAmount >= _lockEth) {
            ethAmount = ethAmount.add(_lockEth);
            if (userInfo[userAddress].staticTime + 3 days < block.timestamp) {
                address(uint160(systemAddress)).transfer(userInfo[userAddress].teamEth.sub(_withdrawTeam.mul(100).div(80)));
                userInfo[userAddress].teamEth = 0;
                earningsInstance.changeWithdrawTeamZero(userAddress);
            }
            userInfo[userAddress].staticTimeout = false;
            userInfo[userAddress].staticTime = 0;
        } else {
            _lockEth = ethAmount;
            ethAmount = ethAmount.mul(2);
        }

        earningsInstance.addActivateEth(userAddress, _lockEth);

        uint256 topProfits = whetherTheCap();
        require(earningsInstance.getWithdrawStatic(msg.sender).mul(100).div(percent - remain) <= topProfits);

        if (initAddressAmount <= 500 && userInfo[userAddress].ethAmount > 0) {
            require(userInfo[userAddress].profitAmount == 0);
        }

        if (ethAmount >= 1 ether && _user.ethAmount == 0) {
            initAddressAmount++;
        }

        calculateBuy(_user, ethAmount, straightAddress, whiteAddress, adminAddress);

        straightReferralReward(_user, ethAmount);

        emit Buy(userAddress, ethAmount, block.timestamp);
    }

    function calculateBuy(
        User storage user,
        uint256 ethAmount,
        address straightAddress,
        address whiteAddress,
        address adminAddress)
    internal
    {
        user.ethAmount = teamRewardInstance.isWhitelistAddress(user.userAddress) ? (ethAmount.mul(110).div(100)).add(user.ethAmount) : ethAmount.add(user.ethAmount);

        if (user.ethAmount > user.refeTopAmount.mul(60).div(100)) {
            user.straightEth += user.lockStraight;
            user.lockStraight = 0;
        }
        if (ethAmount >= 1 ether) {
            if (user.ethAmount.sub(ethAmount) == 0) {
                straightInviteAddress[straightAddress].push(user.userAddress);
                if (straightInviteAddress[straightAddress].length > straightInviteAddress[straightSort[9]].length) {
                    bool has = false;
                    for (uint i = 0; i < 10; i++) {
                        if (straightSort[i] == straightAddress) {
                            has = true;
                        }
                    }
                    if (!has) {
                        straightSort[9] = straightAddress;
                    }
                    quickSort(straightSort, int(0), int(9));
                }
            }

        }

        address(uint160(eggAddress)).transfer(ethAmount.mul(rewardRatio[6]).div(100));

        straightSortRewards += ethAmount.mul(rewardRatio[5]).div(100);

        teamReferralReward(ethAmount, straightAddress);

        terminatorPoolAmount += ethAmount.mul(rewardRatio[4]).div(100);

        calculateToken(user, ethAmount);

        calculateProfit(user, ethAmount);

        updateTeamLevel(straightAddress);

        totalEthAmount += ethAmount;

        whitelistPerformance[whiteAddress] += ethAmount;
        whitelistPerformance[adminAddress] += ethAmount;

        addTerminator(user.userAddress);
    }

    function joinAgain(uint8 type)
    public
    payable
    {   
        amount = msg.value;
        address reinvestAddress = msg.sender;

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        (straightAddress, whiteAddress, adminAddress,) = teamRewardInstance.getUserSystemInfo(msg.sender);

        if (initAddressAmount <= 500) {
            require(!userInfo[reinvestAddress].staticTimeout);
        }

        require(type == 1 || type == 2 || type == 3 || type == 4 || type == 5);

        uint256 earningsProfits = 0;

        if (initAddressAmount <= 100) {
            require(userInfo[reinvestAddress].ethAmount.add(amount) <= investAgain);
        } else if (initAddressAmount <= 500) {
            require(userInfo[reinvestAddress].ethAmount.add(amount) <= investAgain.mul(5));
        }

        if (type == 1) {
            earningsProfits = whetherTheCap();
            uint256 _withdrawStatic;
            uint256 _afterFounds;
            uint256 _withdrawTeam;
            (_withdrawStatic, _afterFounds, _withdrawTeam) = earningsInstance.getStaticAfterFoundsTeam(reinvestAddress);

            _withdrawStatic = _withdrawStatic.mul(100).div(80);
            require(_withdrawStatic.add(userReinvest[reinvestAddress].staticReinvest).add(amount) <= earningsProfits);

            if (amount > _afterFounds) {
                if (userInfo[reinvestAddress].staticTime + 3 days < block.timestamp) {
                    address(uint160(systemAddress)).transfer(userInfo[reinvestAddress].teamEth.sub(_withdrawTeam.mul(100).div(80)));
                    userInfo[reinvestAddress].teamEth = 0;
                    earningsInstance.changeWithdrawTeamZero(reinvestAddress);
                }
                userInfo[reinvestAddress].staticTimeout = false;
                userInfo[reinvestAddress].staticTime = 0;
            }
            userReinvest[reinvestAddress].staticReinvest += amount;
        } else if (type == 2) {
            require(userInfo[reinvestAddress].straightEth > amount);
            userInfo[reinvestAddress].straightEth -= amount;

            earningsProfits = userInfo[reinvestAddress].straightEth;
        } else if (type == 3) {
            require(userInfo[reinvestAddress].straightEth > amount);
            userInfo[reinvestAddress].teamEth -= amount;

            earningsProfits = userInfo[reinvestAddress].teamEth;
        } else if (type == 4) {
            terminatorInstance.reInvestTerminatorReward(reinvestAddress, amount);
            earningsInstance.addActivateEth(reinvestAddress, amount);
        } else if (type == 5) {
            require(whitelistPerformance[reinvestAddress] >= 500 ether);
            uint256 _nodeReward = systemRetain;
            require(userReinvest[reinvestAddress].nodeReinvest.add(amount) <= whitelistPerformance[reinvestAddress].mul(_nodeReward).div(totalEthAmount));
            earningsProfits = (totalEthAmount == 0) ? 0 : whitelistPerformance[reinvestAddress].mul(_nodeReward).div(totalEthAmount).sub(userReinvest[reinvestAddress].nodeReinvest);
            userReinvest[reinvestAddress].nodeReinvest += amount;
        }

        amount = earningsInstance.calculateReinvestAmount(msg.sender, amount, earningsProfits, type);

        calculateBuy(userInfo[reinvestAddress], amount, straightAddress, whiteAddress, adminAddress);

        straightReferralReward(userInfo[reinvestAddress], amount);

        emit JoinAgain(reinvestAddress, amount, type, block.timestamp);
    }

    function goOut(uint256 a, uint8 b)
    public
    {   
        address withdrawAddress = msg.sender;
        require(b == 1 || b == 2 || b == 3 || b == 4 || b == 5);

        uint256 _lockProfits = 0;
        uint256 _userRouteEth = 0;
        uint256 transValue = a.mul(percent - remain).div(100);

        if (b == 1) {
            _userRouteEth = whetherTheCap();
            _lockProfits = SafeMath.mul(a, remain).div(100);
        } else if (b == 2) {
            _userRouteEth = userInfo[withdrawAddress].straightEth;
        } else if (b == 3) {
            if (userInfo[withdrawAddress].staticTimeout) {
                require(userInfo[withdrawAddress].staticTime + 3 days >= block.timestamp);
            } else {
                require(userInfo[withdrawAddress].staticTime == 0);
            }
            _userRouteEth = userInfo[withdrawAddress].teamEth;
        } else if (b == 4) {
            _userRouteEth = a.mul(percent - remain).div(100);
            terminatorInstance.modifyTerminatorReward(withdrawAddress, _userRouteEth);
        } else if (b == 5) {
            require(whitelistPerformance[withdrawAddress] >= 500 ether);
            uint256 _nodeReward = systemRetain;
            _userRouteEth = (totalEthAmount == 0) ? 0 : whitelistPerformance[withdrawAddress].mul(_nodeReward).div(totalEthAmount);
        }

        earningsInstance.routeAddLockEth(withdrawAddress, a, _lockProfits, _userRouteEth, b);

        address(uint160(withdrawAddress)).transfer(transValue);

        emit GoOut(withdrawAddress, a, b, block.timestamp);
    }

    function helpDown(address down)
    public
    payable
    {
        User storage _user = userInfo[msg.sender];
        require(_user.ethAmount >= _user.refeTopAmount.mul(60).div(100));

        uint256 straightTime;
        address refeAddress;
        uint256 ethAmount;
        bool supported;
        (straightTime, refeAddress, ethAmount, supported) = recommendInstance.getRecommendByIndex(index, _user.userAddress);
        require(!supported);

        require(straightTime.add(3 days) >= block.timestamp && refeAddress == subordinate && msg.value >= ethAmount.div(10));

        if (_user.ethAmount.add(msg.value) >= _user.refeTopAmount.mul(60).div(100)) {
            _user.straightEth += ethAmount.mul(rewardRatio[2]).div(100);
        } else {
            _user.lockStraight += ethAmount.mul(rewardRatio[2]).div(100);
        }

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        (straightAddress, whiteAddress, adminAddress,) = teamRewardInstance.getUserSystemInfo(subordinate);
        calculateBuy(userInfo[subordinate], msg.value, straightAddress, whiteAddress, adminAddress);

        recommendInstance.setSupported(index, _user.userAddress, true);

        emit HelpDown(index, subordinate, refeAddress, supported);
    }

    function teamReferralReward(uint256 ethAmount, address referralStraightAddress)
    internal
    {
        if (teamRewardInstance.isWhitelistAddress(msg.sender)) {
            uint256 _systemRetain = ethAmount.mul(rewardRatio[3]).div(100);
            systemRetain += _systemRetain.mul(20).div(100);
            address(uint160(systemAddress)).transfer(_systemRetain.mul(80).div(100));
        } else {
            uint256 _refeReward = ethAmount.mul(rewardRatio[3]).div(100);

            uint256 residueAmount = _refeReward;

            User memory currentUser = userInfo[referralStraightAddress];

            for (uint8 i = 2; i <= 12; i++) {
                address straightAddress = currentUser.straightAddress;

                User storage currentUserStraight = userInfo[straightAddress];
                if (currentUserStraight.level >= i) {
                    uint256 currentReward = _refeReward.mul(teamRatio[i - 2]).div(29);
                    currentUserStraight.teamEth = currentUserStraight.teamEth.add(currentReward);
                    residueAmount = residueAmount.sub(currentReward);
                }

                currentUser = userInfo[straightAddress];
            }

            systemRetain = systemRetain.add(residueAmount.mul(20).div(100));
            address(uint160(systemAddress)).transfer(residueAmount.mul(80).div(100));
        }
    }

    function updateTeamLevel(address refferAddress)
    internal
    {
        User memory currentUserStraight = userInfo[refferAddress];

        uint8 levelUpCount = 0;

        uint256 currentInviteCount = straightInviteAddress[refferAddress].length;
        if (currentInviteCount >= 2) {
            levelUpCount = 2;
        }

        if (currentInviteCount > 12) {
            currentInviteCount = 12;
        }

        uint256 lackCount = 0;
        for (uint8 j = 2; j < currentInviteCount; j++) {
            if (userSubordinateCount[refferAddress][j - 1] >= 1 + lackCount) {
                levelUpCount = j + 1;
                lackCount = 0;
            } else {
                lackCount++;
            }
        }

        if (levelUpCount > currentUserStraight.level) {
            uint8 oldLevel = userInfo[refferAddress].level;
            userInfo[refferAddress].level = levelUpCount;

            if (currentUserStraight.straightAddress != address(0)) {
                if (oldLevel > 0) {
                    if (userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] > 0) {
                        userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] = userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] - 1;
                    }
                }

                userSubordinateCount[currentUserStraight.straightAddress][levelUpCount - 1] = userSubordinateCount[currentUserStraight.straightAddress][levelUpCount - 1] + 1;
                emit LevelDebug(levelUpCount, currentInviteCount, currentUserStraight.level);
                updateTeamLevel(currentUserStraight.straightAddress);
            }
        }
    }

    function calculateProfit(User storage user, uint256 ethAmount)
    internal
    {
        if (teamRewardInstance.isWhitelistAddress(user.userAddress)) {
            ethAmount = ethAmount.mul(110).div(100);
        }

        uint256 userBonus = ethToBonus(ethAmount);
        require(userBonus >= 0 && SafeMath.add(userBonus, totalSupply) >= totalSupply);
        totalSupply += userBonus;
        uint256 tokenDivided = SafeMath.mul(ethAmount, rewardRatio[1]).div(100);
        getPerBonusDivide(tokenDivided, userBonus);
        user.profitAmount += userBonus;
    }

    function getPerBonusDivide(uint256 tokenDivided, uint256 userBonus)
    internal
    {
        uint256 fee = tokenDivided * magnitude;
        perBonusDivide += SafeMath.div(SafeMath.mul(tokenDivided, magnitude), totalSupply);
        fee = fee - (fee - (userBonus * (tokenDivided * magnitude / (totalSupply))));

        int256 updatedPayouts = (int256) ((perBonusDivide * userBonus) - fee);
        payoutsTo[msg.sender] += updatedPayouts;
    }

    function calculateToken(User storage user, uint256 ethAmount)
    internal
    {
        kocInstance.transfer(user.userAddress, ethAmount.mul(ratio));
        user.tokenAmount += ethAmount.mul(ratio);
    }

    function straightReferralReward(User memory user, uint256 ethAmount)
    internal
    {
        address _referralAddresses = user.straightAddress;
        userInfo[_referralAddresses].refeTopAmount = (userInfo[_referralAddresses].refeTopAmount > user.ethAmount) ? userInfo[_referralAddresses].refeTopAmount : user.ethAmount;
        userInfo[_referralAddresses].refeTopAddress = (userInfo[_referralAddresses].refeTopAmount > user.ethAmount) ? userInfo[_referralAddresses].refeTopAddress : user.userAddress;

        recommendInstance.pushRecommend(_referralAddresses, user.userAddress, ethAmount);

        if (teamRewardInstance.isWhitelistAddress(user.userAddress)) {
            uint256 _systemRetain = ethAmount.mul(rewardRatio[2]).div(100);
            systemRetain += _systemRetain.mul(20).div(100);
            address(uint160(systemAddress)).transfer(_systemRetain.mul(80).div(100));
        }
    }

    function straightSortAddress(address referralAddress)
    internal
    {
        for (uint8 i = 0; i < 10; i++) {
            if (straightInviteAddress[straightSort[i]].length < straightInviteAddress[referralAddress].length) {
                address  [] memory temp;
                for (uint j = i; j < 10; j++) {
                    temp[j] = straightSort[j];
                }
                straightSort[i] = referralAddress;
                for (uint k = i; k < 9; k++) {
                    straightSort[k + 1] = temp[k];
                }
            }
        }
    }

    function quickSort(address  [10] storage arr, int left, int right) internal {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = straightInviteAddress[arr[uint(left + (right - left) / 2)]].length;
        while (i <= j) {
            while (straightInviteAddress[arr[uint(i)]].length > pivot) i++;
            while (pivot > straightInviteAddress[arr[uint(j)]].length) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }

    function settleStraightRewards()
    internal
    {
        uint256 addressAmount;
        for (uint8 i = 0; i < 10; i++) {
            addressAmount += straightInviteAddress[straightSort[i]].length;
        }

        uint256 _straightSortRewards = SafeMath.div(straightSortRewards, 2);
        uint256 perAddressReward = SafeMath.div(_straightSortRewards, addressAmount);
        for (uint8 j = 0; j < 10; j++) {
            address(uint160(straightSort[j])).transfer(SafeMath.mul(straightInviteAddress[straightSort[j]].length, perAddressReward));
            straightSortRewards = SafeMath.sub(straightSortRewards, SafeMath.mul(straightInviteAddress[straightSort[j]].length, perAddressReward));
            straightInviteAddress[straightSort[j]].length = 0;
        }
        delete (straightSort);
        currentBlockNumber = block.number;
    }

    function ethToBonus(uint256 ethereum)
    internal
    view
    returns (uint256)
    {
        uint256 _price = bonusPrice * 1e18;
        uint256 _tokensReceived =
        (
        (
        SafeMath.sub(
            (sqrt
        (
            (_price ** 2)
            +
            (2 * (priceIncremental * 1e18) * (ethereum * 1e18))
            +
            (((priceIncremental) ** 2) * (totalSupply ** 2))
            +
            (2 * (priceIncremental) * _price * totalSupply)
        )
            ), _price
        )
        ) / (priceIncremental)
        ) - (totalSupply);

        return _tokensReceived;
    }

    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function myBonusProfits(address user)
    view
    internal
    returns (uint256)
    {
        return (uint256) ((int256)(perBonusDivide * userInfo[user].profitAmount) - payoutsTo[user]) / magnitude;
    }

    function whetherTheCap()
    internal
    returns (uint256)
    {
        require(userInfo[msg.sender].ethAmount.mul(120).div(100) >= userInfo[msg.sender].tokenProfit);
        uint256 _currentAmount = userInfo[msg.sender].ethAmount - userInfo[msg.sender].tokenProfit.mul(100).div(120);
        uint256 topProfits = _currentAmount.mul(remain + 100).div(100);
        uint256 userProfits = myBonusProfits(msg.sender);

        if (userProfits > topProfits) {
            userInfo[msg.sender].profitAmount = 0;
            payoutsTo[msg.sender] = 0;
            userInfo[msg.sender].tokenProfit += topProfits;
            userInfo[msg.sender].staticTime = block.timestamp;
            userInfo[msg.sender].staticTimeout = true;
        }

        if (topProfits == 0) {
            topProfits = userInfo[msg.sender].tokenProfit;
        } else {
            topProfits = (userProfits >= topProfits) ? topProfits : userProfits.add(userInfo[msg.sender].tokenProfit);
        }

        return topProfits;
    }

    function setStraightSortRewards()
    public
    onlyAdmin()
    returns (bool)
    {
        require(currentBlockNumber + blockNumber < block.number);
        settleStraightRewards();
        return true;
    }

    function getStraightSortList()
    public
    view
    returns (address[10] memory)
    {
        return straightSort;
    }

    function getStraightInviteAddress()
    public
    view
    returns (address[] memory)
    {
        return straightInviteAddress[msg.sender];
    }

    function getcurrentBlockNumber()
    public
    view
    returns (uint256){
        return currentBlockNumber;
    }

    function getPurchaseTasksInfo()
    public
    view
    returns (
        uint256 ethAmount,
        uint256 refeTopAmount,
        address refeTopAddress,
        uint256 lockStraight
    )
    {
        User memory getUser = userInfo[msg.sender];
        ethAmount = getUser.ethAmount;
        refeTopAmount = getUser.refeTopAmount;
        refeTopAddress = getUser.refeTopAddress;
        lockStraight = getUser.lockStraight;
    }

    function getPersonalStatistics()
    public
    view
    returns (
        uint256 holdings,
        uint256 dividends,
        uint256 invites,
        uint8 level,
        uint256 afterFounds,
        uint256 referralRewards,
        uint256 teamRewards,
        uint256 nodeRewards
    )
    {
        User memory getUser = userInfo[msg.sender];

        uint256 _withdrawStatic;
        (_withdrawStatic, afterFounds) = earningsInstance.getStaticAfterFounds(getUser.userAddress);

        holdings = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));

        require(getUser.ethAmount.mul(remain + 100).div(100) >= _withdrawStatic.mul(100).div(80));
        uint256 _staticReward = getUser.ethAmount.mul(remain + 100).div(100) - _withdrawStatic.mul(100).div(80);

        require(myBonusProfits(msg.sender).add(getUser.tokenProfit) >= _withdrawStatic.mul(100).div(80));
        uint256 _staticBonus = myBonusProfits(msg.sender).add(getUser.tokenProfit) - _withdrawStatic.mul(100).div(80);

        dividends = (myBonusProfits(msg.sender) >= holdings.mul(remain + 100).div(100)) ? _staticReward : _staticBonus;
        invites = straightInviteAddress[msg.sender].length;
        level = getUser.level;
        referralRewards = getUser.straightEth;
        teamRewards = getUser.teamEth;
        uint256 _nodeRewards = (totalEthAmount == 0) ? 0 : whitelistPerformance[msg.sender].mul(systemRetain).div(totalEthAmount);
        nodeRewards = (whitelistPerformance[msg.sender] < 500 ether) ? 0 : _nodeRewards;
    }

    function getUserBalance()
    public
    view
    returns (
        uint256 staticBalance,
        uint256 recommendBalance,
        uint256 teamBalance,
        uint256 terminatorBalance,
        uint256 nodeBalance
    )
    {
        User memory getUser = userInfo[msg.sender];
        uint256 _currentEth = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));

        uint256 withdrawStraight;
        uint256 withdrawTeam;
        uint256 withdrawStatic;
        uint256 withdrawNode;
        (withdrawStraight, withdrawTeam, withdrawStatic, withdrawNode) = earningsInstance.getUserWithdrawInfo(getUser.userAddress);

        uint256 _staticReward = getUser.ethAmount.mul(remain + 100).div(100) - withdrawStatic.mul(100).div(80);
        uint256 _staticBonus = myBonusProfits(msg.sender).add(getUser.tokenProfit) - withdrawStatic.mul(100).div(80);
        staticBalance = (myBonusProfits(getUser.userAddress) >= _currentEth.mul(remain + 100).div(100)) ? _staticReward.sub(userReinvest[getUser.userAddress].staticReinvest) : _staticBonus.sub(userReinvest[getUser.userAddress].staticReinvest);

        recommendBalance = getUser.straightEth.sub(withdrawStraight.mul(100).div(100 - remain));
        teamBalance = getUser.teamEth.sub(withdrawTeam.mul(100).div(80));
        terminatorBalance = terminatorInstance.getTerminatorRewardAmount(getUser.userAddress);
        uint256 _nodeReward = systemRetain;
        uint256 _nodeEth = (totalEthAmount == 0) ? 0 : whitelistPerformance[getUser.userAddress].mul(_nodeReward).div(totalEthAmount);
        uint256 _nodeBalance = _nodeEth.sub(withdrawNode.mul(100).div(100 - remain)).sub(userReinvest[getUser.userAddress].nodeReinvest);
        nodeBalance = (whitelistPerformance[getUser.userAddress] < 500 ether) ? 0 : _nodeBalance;
    }

    function contractStatistics()
    public
    view
    returns (
        uint256 recommendRankPool,
        uint256 terminatorPool,
        uint256 nodePool
    )
    {
        recommendRankPool = straightSortRewards;
        terminatorPool = terminatorPoolAmount;
        nodePool = systemRetain;
    }

    function listNodeBonus(address node)
    public
    view
    returns (
        address nodeAddress,
        uint256 performance,
        uint256 nodeWithdrawAmount
    )
    {
        nodeAddress = node;
        performance = whitelistPerformance[node];
        nodeWithdrawAmount = earningsInstance.getWithdrawNode(node);
    }

    function listRankOfRecommend()
    public
    view
    returns (
        address[10] memory _straightSort,
        uint256[10] memory _inviteNumber
    )
    {
        for (uint8 i = 0; i < 10; i++) {
            if (straightSort[i] == address(0)){
                break;
            }
            _inviteNumber[i] = straightInviteAddress[straightSort[i]].length;
        }
        _straightSort = straightSort;
    }

    function getCurrentEffectiveUser()
    public
    view
    returns (uint256)
    {
        return initAddressAmount;
    }
    function addTerminator(address addr)
    internal
    {
        uint256 allInvestAmount = userInfo[addr].ethAmount.sub(userInfo[addr].tokenProfit.mul(100).div(120));
        uint256 withdrawAmount = terminatorInstance.checkBlockWithdrawAmount(block.number);
        terminatorInstance.addTerminator(addr, allInvestAmount, block.number, (terminatorPoolAmount - withdrawAmount).div(2));
    }

    function isLockWithdraw()
    public
    view
    returns (
        bool isLock,
        uint256 lockTime
    )
    {
        isLock = userInfo[msg.sender].staticTimeout;
        lockTime = userInfo[msg.sender].staticTime;
    }
}