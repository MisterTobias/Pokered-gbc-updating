GainExperience:
	ld a, [wLinkState]
	cp LINK_STATE_BATTLING
	ret z ; return if link battle
	ld a, [wBoostExpByExpAll]
	ld hl, WithExpAllText
	and a
	jr z, .skipExpAll
	call PrintText
.skipExpAll

	call BufferExpData ; shinpokered all this block
	call GetNumMonsGainingExp
	call DivideExpDataByNumMonsGainingExp
	call GiveStatExp
	call CalculateLevelExp

	xor a
	ld [wWhichPokemon], a
	ld a, [wPartyGainExpFlags]
	and %00111111
	ld c, a
	ld hl, wPartyMon1OTID
.loop
	push bc
	srl c
	jr nc, .next
	push hl		;shin pokered

	call AddExpToPokemon
	ld a, [H_QUOTIENT+2]
	push af
	ld a, [H_QUOTIENT+3]
	push af
	call CapExpAtMaxLevel
	call PrintExpGained
xor a ; PLAYER_PARTY_DATA
	ld [wMonDataLocation], a
	push hl

IF DEF(_EXPBAR)
	callba AnimateEXPBar	;joenote - animate the exp bar
ENDC

	call LoadMonData
	pop hl
	ld bc, wPartyMon1Level - wPartyMon1Exp
	add hl, bc
	push hl
	callba CalcLevelFromExperience
	pop hl
	ld a, [hl]

	ld [wTempCoins1], a

	cp d
	jr z, .nextMon 
	call LevelUpPokemon
.nextMon
	pop af
	ld [H_QUOTIENT+3], a
	pop af
	ld [H_QUOTIENT+2], a
	xor a
	ld [H_QUOTIENT+1], a
	ld [H_QUOTIENT], a
	pop hl
.next
	ld bc, wPartyMon2 - wPartyMon1
	add hl, bc
	ld a, [wWhichPokemon]
	inc a
	ld [wWhichPokemon], a
	pop bc
	srl c
	jr nz, .loop


	ld b, EXP_ALL
	call IsItemInBag
	jr z, .done_doPredefJump

	ld a, [wBoostExpByExpAll]
	and a
	jr nz, .done_doPredefJump

.done_doPredefAndLoop
	ld hl, wPartyGainExpFlags
	xor a
	ld [hl], a
	ld a, [wPlayerMonNumber]
	ld c, a
	ld b, FLAG_SET
	push bc
	predef FlagActionPredef
	ld hl, wPartyFoughtCurrentEnemyFlags
	xor a
	ld [hl], a
	pop bc
	predef FlagActionPredef
	call SetExpAllFlags
	jp GainExperience

.done_doPredefJump
	ld hl, wPartyGainExpFlags
	xor a
	ld [hl], a ; clear gain exp flags
	ld a, [wPlayerMonNumber]
	ld c, a
	ld b, FLAG_SET
	push bc
	predef FlagActionPredef ; set the gain exp flag for the mon that is currently out
	ld hl, wPartyFoughtCurrentEnemyFlags
	xor a
	ld [hl], a
	pop bc
	predef_jump FlagActionPredef 


BufferExpData:
	push de
	ld de, wBuffer
	ld hl, wEnemyMonBaseStats
	ld c, wEnemyMonBaseExp + 1 - wEnemyMonBaseStats
.loop
	ld a, c
	cp 2
	ld a, [hli]
	jr z, .next
	ld [de], a
	inc de
.next
	dec c
	jr nz, .loop
	
	ld b, EXP_ALL
	call IsItemInBag
	jr z, .done

	ld c, NUM_STATS+1
	ld hl, wBuffer
.loop2
	ld a, [hl]
	srl a
	ld [hli], a
	dec c
	jr nz, .loop2

.done	
	pop de
	ret


GetNumMonsGainingExp:
	ld a, [wPartyGainExpFlags]
	ld b, a
	xor a
	ld c, $6
.countSetBitsLoop
	srl b
	adc 0
	dec c
	jr nz, .countSetBitsLoop
	ld [wUnusedD155], a
	ret

DivideExpDataByNumMonsGainingExp:
	ld hl, wBuffer
	ld c, wEnemyMonBaseExp + 1 - wEnemyMonBaseStats - 1
.loop
	ld a, [wUnusedD155]
	cp 2
	ret c	;do nothing if dividing by 1	
	jr z, .div2
	
	cp 3
	jr z, .div3
	
	cp 4
	jr z, .div4
	
	cp 5
	jr z, .div5

	;else divide by 6
.div6
	ld a, [hl]
	call ByteDivBy3
	ld [hl], a
	jr .div2
.div5
	ld a, [hl]
	call ByteDivBy5
	ld [hli], a
	jr .next
.div3
	ld a, [hl]
	call ByteDivBy3
	ld [hli], a
	jr .next
.div4
	ld a, [hl]
	srl a
	ld [hl], a
	;fall through
.div2
	ld a, [hl]
	srl a
	ld [hli], a
.next
	dec c
	jr nz, .loop
	ret

ByteDivBy3:
	ld b, a
	srl b
	sub b
	
	ld b, a
	srl b
	srl b
	add b
	
	ld b, a
	srl b
	srl b
	srl b
	srl b
	add b
	
	push af
	and 1
	ld b, a
	pop af
	
	srl a
	add b
	ret	

ByteDivBy5:
	ld b, a
	srl b
	srl b
	sub b
	
	ld b, a
	srl b
	srl b
	srl b
	srl b
	add b
	
	push af
	and 1
	ld b, a
	pop af
	
	srl a
	srl a
	add b
	ret

GiveStatExp:	
	push de
	ld a, [wPartyGainExpFlags]
	and %00111111 
	ld c, a
	ld hl, wPartyMon1HPExp + 1
.loopPartyMonStatExp
	push bc
	push hl
	srl c
	jr nc, .nextPartyMonStatExp

	ld c, NUM_STATS
	ld de, wBuffer	
.loopPartyMonStatExp_subloop
	ld a, [de]
	ld b, a
	ld a, [hl]
	add b
	ld [hld], a
	ld a, [hl]
	adc 0
	ld [hli], a
	call c, ExpWordOverflow
	inc hl
	inc hl
	inc de
	dec c
	jr nz, .loopPartyMonStatExp_subloop

.nextPartyMonStatExp	
	pop hl
	ld bc, wPartyMon2 - wPartyMon1
	add hl, bc
	pop bc
	srl c
	jr nz, .loopPartyMonStatExp

	pop de
	ret

ExpWordOverflow:
	ld a, $ff
	ld [hld], a
	ld [hli], a
	ret

CalculateLevelExp:
	ld hl, wBuffer + NUM_STATS
	ld a, [hl]
	ld [H_MULTIPLICAND + 2], a
	xor a
	ld [H_MULTIPLICAND + 1], a
	ld [H_MULTIPLICAND], a
	ld a, [wEnemyMonLevel]
	ld [H_MULTIPLIER], a
	call Multiply
	
	ld a, 7
	ld [H_DIVISOR], a
	ld b, 4
	call Divide
	
	ld a, [wIsInBattle]
	dec a
	call nz, BoostExp

	ret


BoostExp:
	ld a, [H_QUOTIENT + 2]
	ld b, a
	ld a, [H_QUOTIENT + 3]
	ld c, a
	srl b
	rr c
	add c
	ld [H_QUOTIENT + 3], a
	ld a, [H_QUOTIENT + 2]
	adc b
	ld [H_QUOTIENT + 2], a
	jr c, .overflow
	ret
.overflow
	ld a, $FF
	ld [H_QUOTIENT + 2], a
	ld [H_QUOTIENT + 3], a
	ret

AddExpToPokemon:
	push de
	
	xor a
	ld [wGainBoostedExp], a
	
	ld a, [H_QUOTIENT + 3]
	ld e, a
	ld a, [H_QUOTIENT + 2]
	ld d, a

	push hl
	ld a, [wPlayerID]
	cp [hl]
	jr nz, .traded
	inc hl
	ld a, [wPlayerID+1]
	cp [hl]
	jr z, .next
.traded
	call BoostExp
	ld a, 1
	ld [wGainBoostedExp], a
.next
	pop hl
	
	ld bc, (wPartyMon1Exp + 2) - wPartyMon1OTID
	add hl, bc
	
	ld a, [hl]
	ld b, a
	ld a, [H_QUOTIENT + 3]
	ld [wExpAmountGained + 1], a
	add b
	ld [hld], a
	
	ld a, [hl]
	ld b, a
	ld a, [H_QUOTIENT + 2]
	ld [wExpAmountGained], a
	adc b
	ld [hld], a
	
	ld a, [hl]
	ld b, a
	ld a, 0
	adc b
	ld [hl], a


	ld a, e
	ld [H_QUOTIENT + 3], a
	ld a, d
	ld [H_QUOTIENT + 2], a
	pop de
	ret


CapExpAtMaxLevel:
	push de	
	push hl
	inc hl
	inc hl
	;HL = wPartyMon'X'Exp + 2
	push hl
	ld a, [wWhichPokemon]
	ld c, a
	ld b, 0
	ld hl, wPartySpecies
	add hl, bc
	ld a, [hl] ; species
	ld [wd0b5], a
	call GetMonHeader
	ld d, MAX_LEVEL
	callab CalcExperience
	ld a, [hExperience]
	ld b, a
	ld a, [hExperience + 1]
	ld c, a
	ld a, [hExperience + 2]
	ld d, a
	pop hl	;HL = wPartyMon'X'Exp + 2
	ld a, [hld]
	sub d
	ld a, [hld]
	sbc c
	ld a, [hl]
	sbc b
	jr c, .next
	ld a, b
	ld [hli], a
	ld a, c
	ld [hli], a
	ld a, d
	ld [hl], a
.next
	pop hl
	pop de
	ret


PrintExpGained:
	push hl
	ld a, [wWhichPokemon]
	ld hl, wPartyMonNicks
	call GetPartyMonName
	ld hl, GainedText
	call PrintText
.noexpprint
	pop hl
	ret


LevelUpPokemon:
IF DEF(_EXPBAR)
	push hl
	callba KeepEXPBarFull
	pop hl
ENDC

	ld a, [wCurEnemyLVL]
	push af		;wCurEnemyLVL is going to be used for stuff, so back up its value
	push hl	;also back up wPartyMon'X'Level

	ld a, d
	ld [hl], a
	ld [wCurEnemyLVL], a
	ld bc, wPartyMon1Species - wPartyMon1Level
	add hl, bc	;HL = wPartyMon'X'Species
	ld a, [hl]
	ld [wd0b5], a
	ld [wd11e], a
	
	push af		;backup the species value
	
	call GetMonHeader
	
	ld bc, (wPartyMon1MaxHP + 1) - wPartyMon1Species
	add hl, bc	
	push hl		;preserve HL = wPartyMon'X'MaxHP + 1
	ld a, [hld]
	ld c, a
	ld b, [hl]	;HL = wPartyMon'X'MaxHP
	push bc ; preserve max HP value (from before level-up)
	
	ld d, h
	ld e, l
	;DE = wPartyMon'X'MaxHP
	ld bc, (wPartyMon1HPExp - 1) - wPartyMon1MaxHP
	add hl, bc	;HL = wPartyMon1HPExp - 1
	ld b, $1 ; consider stat exp when calculating stats
	call CalcStats
	
	pop bc ; restore max HP (from before levelling up) into BC
	pop hl	;restore HL = wPartyMon'X'MaxHP + 1
	ld a, [hld]
	sub c
	ld c, a
	ld a, [hl]
	sbc b
	ld b, a
	ld de, (wPartyMon1HP + 1) - wPartyMon1MaxHP
	add hl, de

	ld a, [hl] ; wPartyMon1HP + 1
	add c
	ld [hld], a
	ld a, [hl] ; HL = wPartyMon'X'HP
	adc b
	ld [hl], a

	ld a, [wPlayerMonNumber]
	ld b, a
	ld a, [wWhichPokemon]
	cp b ; is the current mon in battle?
	jr nz, .printGrewLevelText	
	ld de, wBattleMonHP

	ld a, [hli]
	ld [de], a
	inc de
	ld a, [hl]
	ld [de], a

	ld bc, wPartyMon1Level - (wPartyMon1HP + 1)
	add hl, bc
	push hl 	;preserve HL = wPartyMon'X'Level
	ld de, wBattleMonLevel
	ld bc, 1 + NUM_STATS * 2 ; size of stats
	call CopyData
	pop hl	;restore HL = wPartyMon'X'Level
	ld a, [wPlayerBattleStatus3]
	bit 3, a ; is the mon transformed?
	jr nz, .recalcStatChanges
; the mon is not transformed, so update the unmodified stats
	ld de, wPlayerMonUnmodifiedLevel
	ld bc, 1 + NUM_STATS * 2
	call CopyData
.recalcStatChanges
	xor a ; battle mon
	ld [wCalculateWhoseStats], a
	callab CalculateModifiedStats
	callab ApplyBurnAndParalysisPenaltiesToPlayer
	callab ApplyBadgeStatBoosts
	callab DrawPlayerHUDAndHPBar
	callab PrintEmptyString
	call SaveScreenTilesToBuffer1
.printGrewLevelText
	ld hl, GrewLevelText
	call PrintText
	xor a ; PLAYER_PARTY_DATA
	ld [wMonDataLocation], a

IF DEF(_EXPBAR)
	callba AnimateEXPBarAgain	;joenote - animate exp bar
ENDC

	call LoadMonData	;this clobbers the species value in wd0b5, which is needed for level-up moves
	ld d, $1
	callab PrintStatsBox
	call WaitForTextScrollButtonPress
	call LoadScreenTilesFromBuffer1
	xor a ; PLAYER_PARTY_DATA
	ld [wMonDataLocation], a
	
	pop af			;restore saved species value
	ld [wd0b5], a
	ld [wd11e], a

	ld hl, wCanEvolveFlags
	ld a, [wWhichPokemon]
	ld c, a
	ld b, FLAG_SET
	predef FlagActionPredef

	pop hl	;restore wPartyMon'X'Level
	pop af
	ld [wCurEnemyLVL], a
	ret


SetExpAllFlags:
	push de	
	ld a, $1
	ld [wBoostExpByExpAll], a
	ld a, [wPartyCount]
	ld d, a
	ld e, %00000001
	ld hl, wPartyMon1HP
	ld bc, wPartyMon2HP - wPartyMon1HP
.gainExpFlagsLoop	
	ld a, [hli]
	or [hl] ; is mon's HP 0?
	jp z, .nextmon
	ld a, [wPartyGainExpFlags]
	or e
	ld [wPartyGainExpFlags], a
.nextmon 
	dec hl
	sla e
	add hl, bc
	dec d
	jr nz, .gainExpFlagsLoop
	pop de
	ret


GainedText:
	TX_FAR _GainedText
	TX_ASM
	ld a, [wBoostExpByExpAll]
	ld hl, WithExpAllText
	and a
	ret nz
	ld hl, ExpPointsText
	ld a, [wGainBoostedExp]
	and a
	ret z
	ld hl, BoostedText
	ret

WithExpAllText:
	TX_FAR _WithExpAllText
	TX_ASM
	ld hl, ExpPointsText
	ret

BoostedText:
	TX_FAR _BoostedText

ExpPointsText:
	TX_FAR _ExpPointsText
	db "@"

GrewLevelText:
	TX_FAR _GrewLevelText
	TX_SFX_LEVEL_UP
	db "@"







.partyMonLoop ; loop over each mon and add gained exp
	inc hl
	ld a, [hli]
	or [hl] ; is mon's HP 0?
	jp z, .nextMon ; if so, go to next mon
	push hl
	ld hl, wPartyGainExpFlags
	ld a, [wWhichPokemon]
	ld c, a
	ld b, FLAG_TEST
	predef FlagActionPredef
	ld a, c
	and a ; is mon's gain exp flag set?
	pop hl
	jp z, .nextMon ; if mon's gain exp flag not set, go to next mon
	ld de, (wPartyMon1HPExp + 1) - (wPartyMon1HP + 1)
	add hl, de
	ld d, h
	ld e, l
	ld hl, wEnemyMonBaseStats
	ld c, NUM_STATS
.gainStatExpLoop
	ld a, [hli]
	ld b, a ; enemy mon base stat
	ld a, [de] ; stat exp
	add b ; add enemy mon base state to stat exp
	ld [de], a
	jr nc, .nextBaseStat
; if there was a carry, increment the upper byte
	dec de
	ld a, [de]
	inc a
	jr z, .maxStatExp ; jump if the value overflowed
	ld [de], a
	inc de
	jr .nextBaseStat
.maxStatExp ; if the upper byte also overflowed, then we have hit the max stat exp
	ld a, $ff
	ld [de], a
	inc de
	ld [de], a
.nextBaseStat
	dec c
	jr z, .statExpDone
	inc de
	inc de
	jr .gainStatExpLoop
.statExpDone
	xor a
	ldh [hMultiplicand], a
	ldh [hMultiplicand + 1], a
	ld a, [wEnemyMonBaseExp]
	ldh [hMultiplicand + 2], a
	ld a, [wEnemyMonLevel]
	ldh [hMultiplier], a
	call Multiply
	ld a, 7
	ldh [hDivisor], a
	ld b, 4
	call Divide
	ld hl, wPartyMon1OTID - (wPartyMon1DVs - 1)
	add hl, de
	ld b, [hl] ; party mon OTID
	inc hl
	ld a, [wPlayerID]
	cp b
	jr nz, .tradedMon
	ld b, [hl]
	ld a, [wPlayerID + 1]
	cp b
	ld a, 0
	jr z, .next
.tradedMon
	call BoostExp ; traded mon exp boost
	ld a, 1
.next
	ld [wGainBoostedExp], a
	ld a, [wIsInBattle]
	dec a ; is it a trainer battle?
	call nz, BoostExp ; if so, boost exp
	inc hl
	inc hl
	inc hl
; add the gained exp to the party mon's exp
	ld b, [hl]
	ldh a, [hQuotient + 3]
	ld [wExpAmountGained + 1], a
	add b
	ld [hld], a
	ld b, [hl]
	ldh a, [hQuotient + 2]
	ld [wExpAmountGained], a
	adc b
	ld [hl], a
	jr nc, .noCarry
	dec hl
	inc [hl]
	inc hl
.noCarry
; calculate exp for the mon at max level, and cap the exp at that value
	inc hl
	push hl
	ld a, [wWhichPokemon]
	ld c, a
	ld b, 0
	ld hl, wPartySpecies
	add hl, bc
	ld a, [hl]
	ld [wCurSpecies], a
	call GetMonHeader
	ld d, MAX_LEVEL
	callfar CalcExperience ; get max exp
; compare max exp with current exp
	ldh a, [hExperience]
	ld b, a
	ldh a, [hExperience + 1]
	ld c, a
	ldh a, [hExperience + 2]
	ld d, a
	pop hl
	ld a, [hld]
	sub d
	ld a, [hld]
	sbc c
	ld a, [hl]
	sbc b
	jr c, .next2
; the mon's exp is greater than the max exp, so overwrite it with the max exp
	ld a, b
	ld [hli], a
	ld a, c
	ld [hli], a
	ld a, d
	ld [hld], a
	dec hl
.next2
	push hl
	ld a, [wWhichPokemon]
	ld hl, wPartyMonNicks
	call GetPartyMonName
	ld a, [wBoostExpByExpAll]
	and a
	jr nz, .skipExpText
	ld hl, GainedText
	call PrintText
	xor a ; PLAYER_PARTY_DATA
	ld [wMonDataLocation], a
IF GEN_2_GRAPHICS
	call AnimateEXPBar
ELSE
	call LoadMonData
ENDC
	pop hl
	ld bc, wPartyMon1Level - wPartyMon1Exp
	add hl, bc
	push hl
	farcall CalcLevelFromExperience
	pop hl
	ld a, [hl] ; current level
	cp d
	jp z, .nextMon ; if level didn't change, go to next mon
IF GEN_2_GRAPHICS
	call KeepEXPBarFull
ELSE
	ld a, [wCurEnemyLevel]
ENDC
	push af
	push hl
	ld a, d
	ld [wCurEnemyLevel], a
	ld [hl], a
	ld bc, wPartyMon1Species - wPartyMon1Level
	add hl, bc
	ld a, [hl]
	ld [wCurSpecies], a
	ld [wPokedexNum], a
	call GetMonHeader
	ld bc, (wPartyMon1MaxHP + 1) - wPartyMon1Species
	add hl, bc
	push hl
	ld a, [hld]
	ld c, a
	ld b, [hl]
	push bc ; push max HP (from before levelling up)
	ld d, h
	ld e, l
	ld bc, (wPartyMon1HPExp - 1) - wPartyMon1MaxHP
	add hl, bc
	ld b, $1 ; consider stat exp when calculating stats
	call CalcStats
	pop bc ; pop max HP (from before levelling up)
	pop hl
	ld a, [hld]
	sub c
	ld c, a
	ld a, [hl]
	sbc b
	ld b, a ; bc = difference between old max HP and new max HP after levelling
	ld de, (wPartyMon1HP + 1) - wPartyMon1MaxHP
	add hl, de
; add to the current HP the amount of max HP gained when levelling
	ld a, [hl] ; wPartyMon1HP + 1
	add c
	ld [hld], a
	ld a, [hl] ; wPartyMon1HP + 1
	adc b
	ld [hl], a ; wPartyMon1HP
	ld a, [wPlayerMonNumber]
	ld b, a
	ld a, [wWhichPokemon]
	cp b ; is the current mon in battle?
	jr nz, .printGrewLevelText
; current mon is in battle
	ld de, wBattleMonHP
; copy party mon HP to battle mon HP
	ld a, [hli]
	ld [de], a
	inc de
	ld a, [hl]
	ld [de], a
; copy other stats from party mon to battle mon
	ld bc, wPartyMon1Level - (wPartyMon1HP + 1)
	add hl, bc
	push hl
	ld de, wBattleMonLevel
	ld bc, 1 + NUM_STATS * 2 ; size of stats
	call CopyData
	pop hl
	ld a, [wPlayerBattleStatus3]
	bit TRANSFORMED, a
	jr nz, .recalcStatChanges
; the mon is not transformed, so update the unmodified stats
	ld de, wPlayerMonUnmodifiedLevel
	ld bc, 1 + NUM_STATS * 2
	call CopyData
.recalcStatChanges
	xor a ; battle mon
	ld [wCalculateWhoseStats], a
	callfar CalculateModifiedStats
	callfar ApplyBurnAndParalysisPenaltiesToPlayer
	callfar ApplyBadgeStatBoosts
	callfar DrawPlayerHUDAndHPBar
	callfar PrintEmptyString
	call SaveScreenTilesToBuffer1
.printGrewLevelText
	ld hl, GrewLevelText
	call PrintText
	xor a ; PLAYER_PARTY_DATA
	ld [wMonDataLocation], a
IF GEN_2_GRAPHICS
	call AnimateEXPBarAgain
ELSE
	call LoadMonData
ENDC
	ld d, $1
	callfar PrintStatsBox
	call WaitForTextScrollButtonPress
	call LoadScreenTilesFromBuffer1
	xor a ; PLAYER_PARTY_DATA
	ld [wMonDataLocation], a
	ld a, [wCurSpecies]
	ld [wPokedexNum], a
	predef LearnMoveFromLevelUp
	ld hl, wCanEvolveFlags
	ld a, [wWhichPokemon]
	ld c, a
	ld b, FLAG_SET
	predef FlagActionPredef
	pop hl
	pop af
	ld [wCurEnemyLevel], a

.nextMon
	ld a, [wPartyCount]
	ld b, a
	ld a, [wWhichPokemon]
	inc a
	cp b
	jr z, .done
	ld [wWhichPokemon], a
	ld bc, wPartyMon2 - wPartyMon1
	ld hl, wPartyMon1
	call AddNTimes
	jp .partyMonLoop
.done
	ld hl, wPartyGainExpFlags
	xor a
	ld [hl], a ; clear gain exp flags
	ld a, [wPlayerMonNumber]
	ld c, a
	ld b, FLAG_SET
	push bc
	predef FlagActionPredef ; set the gain exp flag for the mon that is currently out
	ld hl, wPartyFoughtCurrentEnemyFlags
	xor a
	ld [hl], a
	pop bc
	predef_jump FlagActionPredef ; set the fought current enemy flag for the mon that is currently out

; divide enemy base stats, catch rate, and base exp by the number of mons gaining exp

; multiplies exp by 1.5
BoostExp:
	ldh a, [hQuotient + 2]
	ld b, a
	ldh a, [hQuotient + 3]
	ld c, a
	srl b
	rr c
	add c
	ldh [hQuotient + 3], a
	ldh a, [hQuotient + 2]
	adc b
	ldh [hQuotient + 2], a
	ret

GainedText:
	text_far _GainedText
	text_asm
	ld a, [wBoostExpByExpAll]
	ld hl, WithExpAllText
	and a
	ret nz
	ld hl, ExpPointsText
	ld a, [wGainBoostedExp]
	and a
	ret z
	ld hl, BoostedText
	ret

WithExpAllText:
	text_far _WithExpAllText
	text_asm
	ld hl, ExpPointsText
	ret

BoostedText:
	text_far _BoostedText

ExpPointsText:
	text_far _ExpPointsText
	text_end

GrewLevelText:
	text_far _GrewLevelText
	sound_level_up
	text_end
