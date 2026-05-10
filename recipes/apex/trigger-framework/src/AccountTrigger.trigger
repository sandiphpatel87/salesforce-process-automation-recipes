/**
 * AccountTrigger - Single trigger for the Account object.
 *
 * All logic lives in AccountTriggerHandler. This trigger
 * should NEVER contain business logic directly.
 */
trigger AccountTrigger on Account (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    new AccountTriggerHandler().run();
}
